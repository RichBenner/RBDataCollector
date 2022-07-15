/******************************************
Copyright 2016 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*******************************************/

/*  Script:         23_waitstats_last_30_seconds.sql 

    Run as a:       WHOLE SCRIPT (Just F5 it!)

    Impact:         LIGHT (Will not block -- fire away!)

    Contains:       Will take 30 seconds to return...
                        Wait stats over 30-second sample

    Description:    SQL Server Wait Information

                    Community references for waits:
                    sys.dm_os_wait_stats Books Online: http://msdn.microsoft.com/en-us/library/ms179984.aspx
                    sys.dm_os_latch_stats Books Online: https://msdn.microsoft.com/en-us/library/ms175066.aspx

*/
    /********************************* 
    Let's build a list of waits we can safely ignore.
    *********************************/
    IF OBJECT_ID('tempdb..#ignorable_waits') IS NOT NULL 
        DROP TABLE #ignorable_waits;

    CREATE TABLE #ignorable_waits (wait_type nvarchar(256) PRIMARY KEY);

    /* We aren't usign row constructors to be SQL 2005 compatible */
    SET NOCOUNT ON;
    INSERT #ignorable_waits (wait_type) VALUES ('REQUEST_FOR_DEADLOCK_SEARCH');
    INSERT #ignorable_waits (wait_type) VALUES ('SQLTRACE_INCREMENTAL_FLUSH_SLEEP');
    INSERT #ignorable_waits (wait_type) VALUES ('SQLTRACE_BUFFER_FLUSH');
    INSERT #ignorable_waits (wait_type) VALUES ('LAZYWRITER_SLEEP');
    INSERT #ignorable_waits (wait_type) VALUES ('XE_TIMER_EVENT');
    INSERT #ignorable_waits (wait_type) VALUES ('XE_DISPATCHER_WAIT');
    INSERT #ignorable_waits (wait_type) VALUES ('FT_IFTS_SCHEDULER_IDLE_WAIT');
    INSERT #ignorable_waits (wait_type) VALUES ('LOGMGR_QUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('CHECKPOINT_QUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('BROKER_TO_FLUSH');
    INSERT #ignorable_waits (wait_type) VALUES ('BROKER_TASK_STOP');
    INSERT #ignorable_waits (wait_type) VALUES ('BROKER_EVENTHANDLER');
    INSERT #ignorable_waits (wait_type) VALUES ('BROKER_TRANSMITTER');
    INSERT #ignorable_waits (wait_type) VALUES ('SLEEP_TASK');
    INSERT #ignorable_waits (wait_type) VALUES ('SLEEP_SYSTEMTASK');
    INSERT #ignorable_waits (wait_type) VALUES ('WAITFOR');
    INSERT #ignorable_waits (wait_type) VALUES ('DBMIRROR_DBM_MUTEX')
    INSERT #ignorable_waits (wait_type) VALUES ('DBMIRROR_EVENTS_QUEUE')
    INSERT #ignorable_waits (wait_type) VALUES ('DBMIRRORING_CMD');
    INSERT #ignorable_waits (wait_type) VALUES ('DISPATCHER_QUEUE_SEMAPHORE');
    INSERT #ignorable_waits (wait_type) VALUES ('BROKER_RECEIVE_WAITFOR');
    INSERT #ignorable_waits (wait_type) VALUES ('CLR_AUTO_EVENT');
    INSERT #ignorable_waits (wait_type) VALUES ('DIRTY_PAGE_POLL');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_FILESTREAM_IOMGR_IOCOMPLETION');
    INSERT #ignorable_waits (wait_type) VALUES ('ONDEMAND_TASK_QUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('FT_IFTSHC_MUTEX');
    INSERT #ignorable_waits (wait_type) VALUES ('CLR_MANUAL_EVENT');
    INSERT #ignorable_waits (wait_type) VALUES ('SP_SERVER_DIAGNOSTICS_SLEEP');
    INSERT #ignorable_waits (wait_type) VALUES ('CLR_SEMAPHORE');
    INSERT #ignorable_waits (wait_type) VALUES ('DBMIRROR_WORKER_QUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('DBMIRROR_DBM_EVENT');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_CLUSAPI_CALL');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_LOGCAPTURE_WAIT');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_NOTIFICATION_DEQUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_TIMER_TASK');
    INSERT #ignorable_waits (wait_type) VALUES ('HADR_WORK_QUEUE');
    INSERT #ignorable_waits (wait_type) VALUES ('QDS_PERSIST_TASK_MAIN_LOOP_SLEEP');
    INSERT #ignorable_waits (wait_type) VALUES ('QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP');
    INSERT #ignorable_waits (wait_type) VALUES ('QDS_SHUTDOWN_QUEUE');

    /* Want to manually exclude an event and recalculate?*/
    /* insert #ignorable_waits (wait_type) VALUES (''); */


    /********************************* 
    What are the highest waits *right now*? 
    *********************************/    

    /* Note: this is dependent on the #ignorable_waits table created earlier. */
    IF OBJECT_ID('tempdb..#wait_batches') IS NOT NULL
        DROP TABLE #wait_batches;
    IF OBJECT_ID('tempdb..#wait_data') IS NOT NULL
        DROP TABLE #wait_data;

    CREATE TABLE #wait_batches (
        batch_id INT IDENTITY (1,1) PRIMARY KEY,
        sample_time datetime NOT NULL
    );

    CREATE TABLE #wait_data ( 
        batch_id INT NOT NULL ,
        wait_type NVARCHAR(256) NOT NULL ,
        wait_time_ms BIGINT NOT NULL ,
        waiting_tasks BIGINT NOT NULL
    );

    CREATE CLUSTERED INDEX cx_wait_data ON #wait_data(batch_id);

    DECLARE
        @intervals tinyint = 2,
        @delay char(12)='00:00:30.000', /* 30 seconds*/
        @batch_id int,
        @current_interval tinyint = 1,
        @msg nvarchar(max);

    SET NOCOUNT ON;

    WHILE @current_interval <= @intervals
    BEGIN
        INSERT #wait_batches(sample_time)
        SELECT CURRENT_TIMESTAMP;

        SELECT @batch_id=SCOPE_IDENTITY();


        INSERT  #wait_data (batch_id, wait_type, wait_time_ms, waiting_tasks)
        SELECT  @batch_id,
                os.wait_type, 
                SUM(os.wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_wait_time_ms, 
                SUM(os.waiting_tasks_count) OVER (PARTITION BY os.wait_type) AS sum_waiting_tasks
        FROM    sys.dm_os_wait_stats os
                LEFT JOIN #ignorable_waits iw on  os.wait_type=iw.wait_type
        WHERE   iw.wait_type IS NULL
        ORDER BY sum_wait_time_ms DESC;

        SET @msg = CONVERT(CHAR(23),CURRENT_TIMESTAMP,121)+ N': Completed sample ' 
                    + cast(@current_interval AS NVARCHAR(4))
                    + N' of ' + cast(@intervals AS NVARCHAR(4)) 
                    +  '.';

        RAISERROR (@msg,0,1) WITH NOWAIT;
    
        SET @current_interval=@current_interval+1;

        IF @current_interval <= @intervals
            WAITFOR DELAY @delay;
    END;

    /* 
    What were we waiting on?
    This query compares the most recent two samples.
    */
    WITH max_batch AS (
        SELECT TOP 1 batch_id, sample_time
        FROM #wait_batches
        ORDER BY batch_id DESC
    )
    SELECT 
        b.sample_time AS [Second Sample Time],
        DATEDIFF(ss,wb1.sample_time, b.sample_time) AS [Sample Duration in Seconds],
        wd1.wait_type AS [Wait Stat],
        CAST((wd2.wait_time_ms-wd1.wait_time_ms)/1000. AS NUMERIC(10,1)) AS [Wait Time (Seconds)],
        (wd2.waiting_tasks-wd1.waiting_tasks) AS [Number of Waits],
        CASE WHEN (wd2.waiting_tasks-wd1.waiting_tasks) > 0 
        THEN
            CAST((wd2.wait_time_ms-wd1.wait_time_ms)/
                (1.0*(wd2.waiting_tasks-wd1.waiting_tasks)) AS NUMERIC(10,1))
        ELSE 0 END AS [Avg ms Per Wait]
    FROM  max_batch b
    JOIN #wait_data wd2 ON
        wd2.batch_id=b.batch_id
    JOIN #wait_data wd1 ON
        wd1.wait_type=wd2.wait_type AND
        wd2.batch_id - 1 = wd1.batch_id
    JOIN #wait_batches wb1 ON
        wd1.batch_id=wb1.batch_id
    WHERE (wd2.waiting_tasks-wd1.waiting_tasks) > 0
    ORDER BY [Wait Time (Seconds)] DESC;


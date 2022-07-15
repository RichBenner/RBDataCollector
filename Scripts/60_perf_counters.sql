/******************************************
Copyright 2015 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*******************************************/

/*	Script:			60_perf_counters.sql 

	Run as a:		WHOLE SCRIPT WITH PARAMETERS
					(Be sure to set the @collection_interval value
						if you want something other than the default 30 seconds.
					 Bonus: it's re-runnable, too.)

	Contains:		Performance counters

	Description:	Dear Client: You don't need to baseline all of these counters all the time.
					For long term use you want some of these + some basic Windows counters.
					For a list of the core counters we recommend, check out http://brentozar.com/go/perfmon
	
					Memory performance counters:
					How this works:
					Some counters are cumulative after SQL Server restart.
					We take two samples and do a diff between the samples for those counters.
					Note: The average value may not match perfmon exactly. 
					It's averaging over a longer period so it smooths out spiky patterns.

*/

/* ----------------------------------- */
/* BEGIN SECTION: Performance counters */
/* ----------------------------------- */

--Set the collection_interval here
--Then run the whole script. 

DECLARE @collection_interval CHAR(11);
SET @collection_interval = '00:00:30:00' /*hh:mm:ss.ms*/

IF OBJECT_ID('tempdb..#sql_counters_list', 'U') IS NULL 
    BEGIN  
		/* Types in the DMV are NCHAR. We're going variable length here.*/
        CREATE TABLE #sql_counters_list
            (
              [counter_id] SMALLINT IDENTITY NOT NULL ,
              [object_name] VARCHAR(128) NOT NULL ,
              [counter_name] VARCHAR(128) NOT NULL ,
              [instance_name] VARCHAR(128) NULL ,
			  [cntr_type] INT NOT NULL,
              [brent_ozar_unlimited_note] VARCHAR(2000) NULL ,
			  [display_group] TINYINT,
              [display_order] SMALLINT
            );

	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group], [display_order])
	SELECT '', '', NULL, 0, 'Frequently used perf counters from Brent Ozar Unlimited.', 1, -100
	UNION SELECT '', '', NULL, 0, 'Occasionally used perf counters from Brent Ozar Unlimited.', 2, -99

	--Memory Manager Counters
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group], [display_order])
	SELECT 'Memory Manager', 'Memory Grants Pending', NULL, 65792, 'Requests waiting on obtaining a query workspace memory grant. Repeat non-zero values indicate a problem.', 1, -8
	UNION SELECT 'Memory Manager', 'Memory Grants Outstanding', NULL, 65792,'Executing requests that have a query workspace memory grant. These are not a problem.', 1, -9
	UNION SELECT 'Memory Manager', 'Target Server Memory (KB)', NULL, 65792,'The amount of physical memory SQL Server would like to grow to use.', 1, -10
	UNION SELECT 'Memory Manager', 'Total Server Memory (KB)', NULL, 65792,'Committed physical memory in KB in use by the buffer pool.', 1, -11
	;

	--SQL Statistics Counters
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group], [display_order])
	SELECT 'SQL Statistics', 'Batch Requests/sec', NULL, 272696576, 'Num requests: indication of throughput. Higher is better. Dependent on load.', 1, 1
	UNION SELECT 'SQL Statistics', 'SQL Compilations/sec', NULL, 272696576,'Rate of execution plan creation. Includes statement-level recompiles. A recompile may be counted as two compiles (so this can be higher than Batch Requests/sec at times).', 1, 2
	UNION SELECT 'SQL Statistics', 'SQL Re-Compilations/sec', NULL, 272696576,'Rate of re-creation of execution plans (for statements which already had them).', 1, 3
	UNION SELECT 'SQL Statistics', 'Forced Parameterizations/sec', NULL, 272696576,'Statements with literals forced to parameterize. Caused by database setting OR a certain type of plan guide.', 1, 4
	UNION SELECT 'SQL Statistics', 'Auto-Param Attempts/sec', NULL, 272696576,'Failed + Safe + Unsafe auto-parameterized statements (but not forced)', 2, 5
	UNION SELECT 'SQL Statistics', 'Safe Auto-Params/sec', NULL, 272696576,'Simple parameterization attempts (deemed safe for re-use).', 2, 6
	UNION SELECT 'SQL Statistics', 'Unsafe Auto-Params/sec', NULL, 272696576,'Simple parameterization attempts-- but plans NOT judged safe for re-use', 2, 7
	UNION SELECT 'SQL Statistics', 'Failed Auto-Params/sec', NULL, 272696576,'Failed simple paramaterization attempts.', 2,  8
	UNION SELECT 'SQL Statistics', 'Guided Plan Executions/sec', NULL, 272696576,'Executions where plan dictated by a plan guide (does not include plan guides that force or parameterization or force literals).', 2, 9
	UNION SELECT 'SQL Statistics', 'Misguided Plan Executions/sec', NULL, 272696576,'Attempted to use a plan guide, but could not. Disregarded the plan guide.', 2, 10
	UNION SELECT 'SQL Statistics', 'SQL Attention rate', NULL, 272696576,'Attention requests (cancellation requests) from the client.', 2,  11
	;

	--General Statistics
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group],  [display_order])
	SELECT 'General Statistics', 'Logins/sec', NULL, 272696576, 'Incoming logins-- execept for logins started from the connection pool.', 1, 15
	UNION SELECT 'General Statistics', 'Logouts/sec', NULL, 272696576,'Goodbye!', 1, 16
	UNION SELECT 'General Statistics', 'Connection Resets/sec', NULL, 272696576,'Logins started from the connection pool.', 1, 17
	UNION SELECT 'General Statistics', 'User Connections', NULL, 65792,'Number of users connected (total).', 1, 14
	;
	--Access Methods
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group],  [display_order])
	SELECT 'Access Methods', 'Full Scans/sec', NULL, 272696576, 'Clustered index or table scans-- but they don''t necessarily read all the rows in the index/table!', 2, 21
	UNION SELECT 'Access Methods', 'Range Scans/sec', NULL, 272696576,'Scans a range of rows in an index. Could be a few rows, could be a lot. May look like a seek in a query plan.', 2,  22
	UNION SELECT 'Access Methods', 'Probe Scans/sec', NULL, 272696576,'These pull just a single, qualified row in a table or index.', 2, 23
	UNION SELECT 'Access Methods', 'Forwarded Records/sec', NULL, 272696576,'How many times SQL Server had to follow a forwarding address pointer. (Heaps only.)', 1, 24
	UNION SELECT 'Access Methods', 'Skipped Ghosted Records/sec', NULL, 272696576,'How many "ghost" records skipped during scans. Ghosts are marked as deleted but not yet cleaned up.', 2, 25
	UNION SELECT 'Access Methods', 'Extents Allocated/sec', NULL, 272696576,'Number of sets of 8 pages allocated (whole instance).', 2, 26
	UNION SELECT 'Access Methods', 'Extent Deallocations/sec', NULL, 272696576,'Number of sets of 8 pages deallocated (whole instance).', 2, 27
	;

	--Buffer Manager
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group],  [display_order])
	SELECT 'Buffer Manager', 'Free list stalls/sec', NULL, 272696576, 'Requests that had to wait due to lack of free list space in memory. The free list is maintained by the lazywriter.', 2, 31
	UNION SELECT 'Buffer Manager', 'Lazy writes/sec', NULL, 272696576,'Pages written to disk from memory by the lazy writer.', 2, 32
	UNION SELECT 'Buffer Manager', 'Checkpoint pages/sec', NULL, 272696576,'Pages flushed to disk by a checkpoint.', 2, 33
	UNION SELECT 'Buffer Manager', 'Page lookups/sec', NULL, 272696576,'Count of all pages fetched from the buffer pool.', 2, 30
	UNION SELECT 'Buffer Manager', 'Page reads/sec', NULL, 272696576,'Physical pages read from disk (couldn''t be read from memory, all DBs).', 1, -4
	UNION SELECT 'Buffer Manager', 'Readahead pages/sec', NULL, 272696576,'Pages read into memory from disk using asyncrhonous pre-fetching.', 2, 36
	UNION SELECT 'Buffer Manager', 'Page life expectancy', NULL, 65792,'Estimated seconds SQL believes a data page is likely to stay in the buffer pool.', 1, -5
	;
	--Lock Manager 
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group],  [display_order])
	SELECT 'Locks', 'Number of Deadlocks/sec', '_Total', 272696576, 'Number of lock requests that ended in a deadlock.', 1, 41
	UNION SELECT 'Locks', 'Lock Requests/sec', '_Total', 272696576,'Number of requests for a lock (they may not have to wait for it).',2, 42
	UNION SELECT 'Locks', 'Lock Waits/sec', '_Total', 272696576,'Number of lock requests had to wait (blocking, etc).', 2, 42
	;

	--Databases
	INSERT [#sql_counters_list] ( [object_name], [counter_name], [instance_name], [cntr_type], [brent_ozar_unlimited_note], [display_group],  [display_order])
	SELECT 'Databases', 'Log Flushes/sec', '_Total', 272696576, 'Number of individually committed transactions.', 2, 51
	UNION SELECT 'Databases', 'Log Flush Waits/sec', '_Total', 272696576,'Number of committed transactions waiting.', 2, 52
	UNION SELECT 'Databases', 'Log Bytes Flushed/sec', '_Total', 272696576,'Bytes flushed to the transaction log in this period.', 2, 53
	UNION SELECT 'Databases', 'Log Flush Wait Time', '_Total', 65792,'Milliseconds waiting on flushing the log.', 2, 54
	UNION SELECT 'Databases', 'Data File(s) Size(KB)', '_Total', 272696576,'Diff between total size of data files: if 0 then no growth in the sample period.', 1, 55
	;

	END

IF OBJECT_ID('tempdb..#sql_counters_data', 'U') IS NULL 
    BEGIN  
        CREATE TABLE #sql_counters_data
            (
              [batch_id] TINYINT NOT NULL ,
              [collection_time] DATETIME NOT NULL
                                         DEFAULT GETDATE() ,
              [object_name] VARCHAR(128) NOT NULL ,
              [counter_name] VARCHAR(128) NOT NULL ,
              [instance_name] VARCHAR(128) NULL ,
              [cntr_value] BIGINT NOT NULL,
		    )
    END
ELSE 
    BEGIN
        TRUNCATE TABLE [#sql_counters_data];
    END  

/*Collect first sample.*/
INSERT  [#sql_counters_data]
        ( [batch_id] , [object_name] , [counter_name] , [instance_name] , [cntr_value] )
        SELECT  1 AS [batch_id] ,
                CAST(RTRIM(perf.[object_name]) AS VARCHAR(128)) ,
                CAST(RTRIM(perf.[counter_name]) AS VARCHAR(128)) ,
                CAST(RTRIM(perf.[instance_name]) AS VARCHAR(128)) ,
                perf.[cntr_value]
        FROM    sys.[dm_os_performance_counters] AS perf
                JOIN #sql_counters_list ctrs ON RTRIM(perf.[counter_name]) COLLATE SQL_Latin1_General_CP1_CI_AS = ctrs.[counter_name] COLLATE SQL_Latin1_General_CP1_CI_AS
                                                AND ( ctrs.[instance_name] IS NULL
                                                     OR ( RTRIM(perf.[instance_name]) COLLATE SQL_Latin1_General_CP1_CI_AS = ctrs.[instance_name] COLLATE SQL_Latin1_General_CP1_CI_AS)
												) AND perf.[cntr_type] = ctrs.[cntr_type]
        WHERE   CHARINDEX(ctrs.[object_name] COLLATE SQL_Latin1_General_CP1_CI_AS, perf.[object_name] COLLATE SQL_Latin1_General_CP1_CI_AS) > 0;


/*Wait.*/
WAITFOR DELAY @collection_interval;


/*Collect second sample.*/
INSERT  [#sql_counters_data]
        ( [batch_id] , [object_name] , [counter_name] , [instance_name] , [cntr_value] )
        SELECT  2 AS [batch_id] ,
                CAST(RTRIM(perf.[object_name]) AS VARCHAR(128)) ,
                CAST(RTRIM(perf.[counter_name]) AS VARCHAR(128)) ,
                CAST(RTRIM(perf.[instance_name]) AS VARCHAR(128)) ,
                perf.[cntr_value]
        FROM    sys.[dm_os_performance_counters] AS perf
                JOIN #sql_counters_list ctrs ON RTRIM(perf.[counter_name]) COLLATE SQL_Latin1_General_CP1_CI_AS = ctrs.[counter_name] COLLATE SQL_Latin1_General_CP1_CI_AS
                                                AND ( ctrs.[instance_name] IS NULL
                                                     OR ( RTRIM(perf.[instance_name]) COLLATE SQL_Latin1_General_CP1_CI_AS = ctrs.[instance_name] COLLATE SQL_Latin1_General_CP1_CI_AS)
												) AND perf.[cntr_type] = ctrs.[cntr_type]
        WHERE   CHARINDEX(ctrs.[object_name] COLLATE SQL_Latin1_General_CP1_CI_AS, perf.[object_name] COLLATE SQL_Latin1_General_CP1_CI_AS) > 0;
                                               
/*Return the difference*/
/*Group 1: frequently useful.*/
;WITH    [perf_sample]
          AS ( SELECT   [batch_id] ,
                        [collection_time] ,
                        [object_name] ,
                        [counter_name] ,
                        [instance_name] ,
                        [cntr_value]
               FROM     [#sql_counters_data]
             )
    SELECT  COALESCE(DATEDIFF(ss, [sample_1].[collection_time], [sample_2].[collection_time]),0) AS [Seconds] ,
            COALESCE([sample_1].[object_name],ctrs.[object_name]) AS [Perf Object] ,
            COALESCE([sample_1].[counter_name],ctrs.[counter_name]) AS [Perf Counter] ,
			CASE WHEN [ctrs].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN [sample_2].[cntr_value] - [sample_1].[cntr_value]
					 ELSE 0
				END 
			ELSE [sample_2].[cntr_value] /*if not a per-sec counter, just take the second sample's value*/
			END
				AS [Total Count] ,
			CASE WHEN [ctrs].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN CAST(( [sample_2].[cntr_value] - [sample_1].[cntr_value] ) / 
						( 1.0 * DATEDIFF(ss,[sample_1].[collection_time],[sample_2].[collection_time]) ) 
						AS NUMERIC(20,1))
					 ELSE 0
				END
			ELSE NULL /*Not a per-sec counter-- leave it blank*/
            END AS [Average Per Sec] ,
            ctrs.[brent_ozar_unlimited_note] AS [Brent Ozar Unlimited Note]
    FROM   #sql_counters_list ctrs
		LEFT OUTER JOIN [perf_sample] AS sample_1 ON [sample_1].[counter_name] = ctrs.[counter_name] AND
			[sample_1].[batch_id] = 1      
        LEFT OUTER JOIN [perf_sample] AS sample_2 ON [sample_2].[batch_id] = [sample_1].[batch_id] + 1
			AND [sample_2].[object_name] = [sample_1].[object_name]
            AND [sample_2].[counter_name] = [sample_1].[counter_name]
            AND [sample_2].[instance_name] = [sample_2].[instance_name]
	WHERE ctrs.display_group=1
		AND (ctrs.counter_name='' OR [sample_1].[counter_name] IS NOT NULL)
    ORDER BY ctrs.display_order;

    /*
/*Group 2: Detailed trending/ extra info.*/
;WITH    [perf_sample]
          AS ( SELECT   [batch_id] ,
                        [collection_time] ,
                        [object_name] ,
                        [counter_name] ,
                        [instance_name] ,
                        [cntr_value]
               FROM     [#sql_counters_data]
             )
    SELECT  COALESCE(DATEDIFF(ss, [sample_1].[collection_time], [sample_2].[collection_time]),0) AS [Seconds] ,
            COALESCE([sample_1].[object_name],ctrs.[object_name]) AS [Perf Object] ,
            COALESCE([sample_1].[counter_name],ctrs.[counter_name]) AS [Perf Counter] ,
			CASE WHEN [ctrs].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN [sample_2].[cntr_value] - [sample_1].[cntr_value]
					 ELSE 0
				END 
			ELSE [sample_2].[cntr_value] /*if not a per-sec counter, just take the second sample's value*/
			END
				AS [Total Count] ,
			CASE WHEN [ctrs].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN CAST(( [sample_2].[cntr_value] - [sample_1].[cntr_value] ) / 
						( 1.0 * DATEDIFF(ss,[sample_1].[collection_time],[sample_2].[collection_time]) ) 
						AS NUMERIC(20,1))
					 ELSE 0
				END
			ELSE NULL /*Not a per-sec counter-- leave it blank*/
            END AS [Average Per Sec] ,
            ctrs.[brent_ozar_unlimited_note] AS [Brent Ozar Unlimited Note]
    FROM   #sql_counters_list ctrs
		LEFT OUTER JOIN [perf_sample] AS sample_1 ON [sample_1].[counter_name] = ctrs.[counter_name] AND
			[sample_1].[batch_id] = 1      
        LEFT OUTER JOIN [perf_sample] AS sample_2 ON [sample_2].[batch_id] = [sample_1].[batch_id] + 1
			AND [sample_2].[object_name] = [sample_1].[object_name]
            AND [sample_2].[counter_name] = [sample_1].[counter_name]
            AND [sample_2].[instance_name] = [sample_2].[instance_name]
	WHERE ctrs.display_group=2
		AND (ctrs.counter_name='' OR [sample_1].[counter_name] IS NOT NULL)
    ORDER BY ctrs.display_order;

    */
/* --------------------------------- */
/* END SECTION: Performance counters */
/* --------------------------------- */

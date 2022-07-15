/******************************************
Copyright 2015 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*******************************************/

/*	Script:			51_memory_by_db.sql 

	Run as a:		WHOLE SCRIPT (F5 away!)

	Contains:		Buffer page utilization by database, table, and index

	Description:	Buffer page utilization by database, table, and index:
						    As a word of warning, defer to the query in 50_memory.sql
							  for servers with a large number of databases - this query will hit
							  dm_os_buffer_descriptors once per database.
*/

/* -------------------------------------------------------------------- */
/* BEGIN SECTION: Buffer page utilization by database, table, and index */
/* -------------------------------------------------------------------- */

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @command AS NVARCHAR(MAX);

	IF OBJECT_ID('tempdb..#memory') IS NULL
	BEGIN
		CREATE TABLE #memory
		(
		 database_name SYSNAME ,
		 cached_pages_count BIGINT ,
		 cached_pages_mb MONEY ,
		 table_name NVARCHAR(257) , -- it's a double SYSNAME plus a period
		 index_name SYSNAME,
		 free_space_in_bytes BIGINT
		);
	END
	ELSE
	BEGIN
		TRUNCATE TABLE #memory;
	END

	IF OBJECT_ID('tempdb..#buffers') IS NULL
	BEGIN
		CREATE TABLE #buffers
		(
		  database_id INT,
		  allocation_unit_id BIGINT,
		  free_space_in_bytes BIGINT,
		  buffered_page_count BIGINT
		);

		CREATE CLUSTERED INDEX cx_buffers
		ON #buffers(database_id, allocation_unit_id);
	END
	ELSE
	BEGIN
		TRUNCATE TABLE #buffers;
	END

	INSERT INTO #buffers
	SELECT  database_id
			, allocation_unit_id
			, SUM(CAST(free_space_in_bytes AS BIGINT))
			, COUNT(*)
	FROM    sys.dm_os_buffer_descriptors 
	GROUP BY database_id
			, allocation_unit_id ;

	SET @command = 'INSERT  INTO #memory (database_name, cached_pages_count, cached_pages_mb, table_name, index_name, free_space_in_bytes)
	SELECT  DB_NAME(), COUNT_BIG(*), CAST((SUM(buffered_page_count) * 8192) / 1024. / 1024. AS MONEY),
			obj.[schema_name] + ''.'' + obj.name, CASE WHEN i.name IS NULL THEN ''HEAP'' ELSE i.name END,
			SUM(CAST(free_space_in_bytes AS BIGINT))
	FROM    #buffers AS bd ' + N'
			INNER JOIN (SELECT  DB_ID() AS db_id, OBJECT_NAME(p.object_id) AS name,
								OBJECT_SCHEMA_NAME(p.object_id) AS [schema_name],
								index_id, allocation_unit_id, total_pages
						FROM    sys.allocation_units AS au
								INNER JOIN sys.partitions AS p ON au.container_id = p.hobt_id AND (au.type = 1 OR au.type = 3)
								INNER JOIN sys.objects AS o ON p.object_id = o.object_id
						WHERE   o.is_ms_shipped = 0
						UNION ALL ' + N'
						SELECT  DB_ID() AS db_id, OBJECT_NAME(p.object_id) AS name,
								OBJECT_SCHEMA_NAME(p.object_id) AS [schema_name],
								index_id, allocation_unit_id, total_pages
						FROM    sys.allocation_units AS au
								INNER JOIN sys.partitions AS p ON au.container_id = p.partition_id AND au.type = 2
								INNER JOIN sys.objects AS o ON p.object_id = o.object_id
						WHERE   o.is_ms_shipped = 0
						) AS obj ON bd.allocation_unit_id = obj.allocation_unit_id AND bd.database_id = obj.db_id ' + N'
			LEFT JOIN sys.indexes AS i ON i.index_id = obj.index_id AND i.object_id = OBJECT_ID(DB_NAME() + ''.'' + obj.schema_name + ''.'' + obj.name, ''U'')
	WHERE   database_id = DB_ID()
	GROUP BY obj.[schema_name] + ''.'' + obj.name ,
			i.name ' + N'
	OPTION (RECOMPILE);'

	/* If it's regular SQL Server, check memory for each database. */
	IF CAST(SERVERPROPERTY('edition') AS VARCHAR(100)) <> 'SQL Azure'
		SET @command = 'sp_MSforeachdb ''USE [?];' + REPLACE(@command, '''', '''''') + '''';

	EXEC(@command);

	-- by database
	SELECT  database_name [Database Name]
			, SUM(cached_pages_mb) [Cached Data (MB)]
			, SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.) AS [Free Space (MB)]
			, CASE SUM(cached_pages_mb) WHEN 0 THEN 0
				   ELSE CAST(100 * (SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.)
						/ SUM(cached_pages_mb)) AS MONEY) 
			  END AS [% Free]
	FROM    #memory as m
	GROUP BY database_name
	ORDER BY 2 DESC
	OPTION (RECOMPILE); 



	-- by table
	SELECT  database_name [Database Name]
			, table_name [Table Name]
			, SUM(cached_pages_mb) [Cached Data (MB)]
			, SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.) AS [Free Space (MB)]
			, CASE SUM(cached_pages_mb) WHEN 0 THEN 0
				   ELSE CAST(100 * (SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.)
						/ SUM(cached_pages_mb)) AS MONEY) 
			  END AS [% Free]
	FROM    #memory as m
	GROUP BY database_name, table_name
	ORDER BY 3 DESC, database_name
	OPTION (RECOMPILE);


	-- by index
	SELECT  database_name [Database Name]
			, table_name [Table Name]
			, index_name [Index Name]
			, SUM(cached_pages_mb) [Cached Data (MB)]
			, SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.) AS [Free Space (MB)]
			, CASE SUM(cached_pages_mb) WHEN 0 THEN 0
				   ELSE CAST(100 * (SUM(CAST(free_space_in_bytes AS BIGINT)) / (1024. * 1024.)
						/ SUM(cached_pages_mb)) AS MONEY) 
			  END AS [% Free]
	FROM    #memory AS m
	GROUP BY database_name, table_name, index_name
	ORDER BY 4 DESC, database_name
	OPTION (RECOMPILE);

/* ------------------------------------------------------------------ */
/* END SECTION: Buffer page utilization by database, table, and index */
/* ------------------------------------------------------------------ */


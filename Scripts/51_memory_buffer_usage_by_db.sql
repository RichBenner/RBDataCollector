/******************************************
Copyright 2016 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*******************************************/

/*	Script:			50_memory.sql 

	Run as a:		SECTION

	Contains:		Memory performance counters
					Buffer page usage
					Buffer page by database, by NUMA node (SQL 2008 and higher)
					Memory usage for the plan cache

	Description:	Memory performance counters:
						Look at:
							Target and total server memory
							Page life expectancy (need to baseline this for it to be super-valuable)
							Other counters may be useful if you suspect memory pressure.
						
					Buffer page usage:
						With the amount of free space on cached pages and the total for all DBs.
						Adapted (significantly) from: "sys.dm_os_buffer_descriptors" in Books Online
							http://msdn.microsoft.com/en-us/library/ms173442.aspx

					Buffer page usage by database, by NUMA node:
						Same as the previous query, but for systems with multiple NUMA nodes.
						To see the overhead of accessing memory across different NUMA nodes,
						run coreinfo -m to dump NUMA cost outputs:
						http://technet.microsoft.com/en-us/sysinternals/cc835722

*/


/* -------------------------------------------- */
/* BEGIN SECTION: Buffer page usage by database */
/* -------------------------------------------- */

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	WITH    memory
			  AS (SELECT    CAST(COUNT(*) * 8 / 1024.0 AS NUMERIC(10, 2)) AS [Cached Data MB] ,
							CAST(SUM(CAST(free_space_in_bytes AS BIGINT)) / 1024. / 1024. AS NUMERIC(10, 2)) AS [Free MB] ,
							CASE database_id
							  WHEN 32767 THEN 'ResourceDb'
							  ELSE DB_NAME(database_id)
							END AS [DB Name]
				  FROM      sys.dm_os_buffer_descriptors
				  GROUP BY  DB_NAME(database_id) ,
							database_id
				 )
	--The detail by database
	SELECT  [Cached Data MB] ,
			[Free MB] ,
			CONVERT(NUMERIC(6, 2), ([Free MB] / [Cached Data MB]) * 100) AS [% Free] ,
			[DB Name]
	FROM    memory
	UNION
	--And now the total
	SELECT  SUM([Cached Data MB]) AS [Cached Data MB] ,
			SUM([Free MB]) AS [Free MB] ,
			CONVERT(NUMERIC(6, 2), (100 * SUM(CAST([Free MB] AS BIGINT)) / SUM(CAST([Cached Data MB] AS BIGINT)))) AS [% Free] ,
			N'***ALL DATABASES***' AS [DB Name]
	FROM    memory
	ORDER BY [Cached Data MB] DESC
	OPTION (RECOMPILE);
	

/* -------------------------------------------- */
/* END SECTION: Buffer page usage by database   */
/* -------------------------------------------- */

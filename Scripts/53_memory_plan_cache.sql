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

/* ---------------------------------------------- */
/* BEGIN SECTION: Memory usage for the plan cache */
/* ---------------------------------------------- */
	WITH    plancache
			  AS (SELECT    objtype ,
							COUNT(*) count_of_plans ,
							CAST(SUM(CAST(size_in_bytes AS BIGINT)) / 1024. / 1024. AS NUMERIC(10, 1)) AS mb_all_plans ,
							SUM(CAST(usecounts AS BIGINT)) AS total_usecount ,
							AVG(CAST(usecounts AS BIGINT)) AS avg_usecount ,
							SUM(CASE WHEN usecounts = 1
										  AND cacheobjtype <> 'Compiled Plan Stub' THEN 1
									 ELSE 0
								END) AS count_single_use_plans ,
							CAST(SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT)
										  ELSE 0
									 END) / 1024. / 1024. AS NUMERIC(10, 1)) AS total_mb_single_use_plans
				  FROM      sys.dm_exec_cached_plans
				  GROUP BY  objtype
				 )
		SELECT  objtype as [Object Type] ,
				count_of_plans AS [Plan Count] ,
				mb_all_plans AS [Total MB] ,
				total_usecount AS [Total Use Count] ,
				avg_usecount AS [Avg Use Count] ,
				count_single_use_plans AS [Count Single-Use Plans] ,
				total_mb_single_use_plans AS [Total MB Single-Use Plans] ,
				CASE WHEN mb_all_plans > 0 THEN CAST(100 * total_mb_single_use_plans / mb_all_plans AS NUMERIC(10, 1))
					 ELSE 0
				END AS [% Space Single-Use Plans]
		FROM    plancache
		UNION ALL
		SELECT  '***Entire Cache***' ,
				SUM(count_of_plans) ,
				SUM(mb_all_plans) ,
				SUM(total_usecount) ,
				AVG(total_usecount) ,
				SUM(count_single_use_plans) ,
				SUM(total_mb_single_use_plans) ,
				CASE WHEN SUM(mb_all_plans) > 0
					 THEN CAST(100 * SUM(total_mb_single_use_plans) / SUM(mb_all_plans) AS NUMERIC(10, 1))
					 ELSE 0
				END AS percent_space_single_use_plans
		FROM    plancache
		ORDER BY mb_all_plans DESC
	OPTION  (RECOMPILE) ;


/* -------------------------------------------- */
/* END SECTION: Memory usage for the plan cache */
/* -------------------------------------------- */

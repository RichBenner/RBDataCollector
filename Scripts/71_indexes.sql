/*	Script:			71_indexes.sql

	Run as a:		Set of individual queries, run one by one.

	Impact:			LIGHT, but large amounts of partitions can slow some queries down.

	Contains:		Index information when sp_BlitzIndex isn't the best choice.
*/



/* Heaps
Adapted from http://sqlserverpedia.com/wiki/Find_Tables_Without_Primary_Keys
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
;WITH    partition_stats
          AS ( SELECT ps.object_id,
					QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) AS [Heap],
                    ps.index_id ,
                    SUM(ps.row_count) AS row_count ,
                    CAST(SUM(ps.reserved_page_count) * 8. / 1024. AS NUMERIC(10, 2)) AS reserved_mb ,
                    COUNT(*) AS num_partitions
                FROM sys.dm_db_partition_stats ps
	            JOIN sys.objects o
		            ON ps.object_id = o.object_id
                JOIN sys.partitions AS par on ps.partition_id=par.partition_id
                WHERE ps.index_id = 0
					AND o.is_ms_shipped=0
                GROUP BY ps.object_id ,o.schema_id,o.name, ps.index_id
             )
    SELECT [Heap],
            ps.row_count ,
            ps.reserved_mb ,
            ps.num_partitions ,
			nc_index_count = (SELECT COUNT(*) FROM sys.indexes iNCL WHERE i.object_id = iNCL.object_id AND i.index_id <> iNCL.index_id),
            user_seeks ,
            user_scans ,
            user_lookups ,
            user_updates ,
            last_user_seek ,
            last_user_scan ,
            last_user_lookup
        FROM sys.indexes i
            JOIN partition_stats ps
                ON i.object_id = ps.object_id
                   AND i.index_id = ps.index_id
            LEFT OUTER JOIN sys.dm_db_index_usage_stats ius
                ON ius.database_id = DB_ID()
                   AND i.object_id = ius.object_id
                   AND i.index_id = ius.index_id
        WHERE i.type_desc='HEAP' AND i.data_space_id<>0 /*exclude TVFs*/
        ORDER BY row_count DESC;
GO



/* Table sizes, total non-clustered index size by table, row count, and LOB data.
Copyright 2015 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) AS table_name ,
        SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN ps.row_count
                 ELSE 0
            END) AS table_row_count ,
        SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN 0
                 ELSE 1
            END) AS nc_index_count ,
		CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN ps.reserved_page_count
                      ELSE 0
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS table_reserved_MB ,
        CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN 0
                      ELSE ps.reserved_page_count
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS nc_reserved_MB ,
		--new field
		CASE WHEN SUM(ps.reserved_page_count) <> 0 THEN
		 		CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN 0
                      ELSE ps.reserved_page_count
                 END) * 8. / 1024. AS NUMERIC(10, 2))
				 /
				 CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN ps.reserved_page_count
                      ELSE 0
                 END) * 8. / 1024. AS NUMERIC(10, 2))
		ELSE 0
		END AS nc_ratio,
        CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN ps.lob_reserved_page_count
                      ELSE 0
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS table_lob_reserved_MB ,
        CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN ps.row_overflow_reserved_page_count
                      ELSE 0
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS table_row_overflow_reserved_MB ,
        CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN 0
                      ELSE ps.lob_reserved_page_count
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS nc_lob_reserved_MB ,
        CAST(SUM(CASE WHEN ps.index_id IN ( 0, 1 ) THEN 0
                      ELSE ps.row_overflow_reserved_page_count
                 END) * 8. / 1024. AS NUMERIC(10, 2)) AS nc_row_overflow_reserved_MB
    FROM sys.dm_db_partition_stats ps
        JOIN sys.objects o
            ON ps.object_id = o.object_id
        JOIN sys.partitions AS par on ps.partition_id=par.partition_id
    WHERE o.is_ms_shipped = 0
    GROUP BY ps.object_id ,
        QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
	ORDER BY nc_ratio DESC ;
    --ORDER BY table_reserved_MB DESC;
GO




/* Indexes not in use - from http://sqlserverpedia.com/wiki/Find_Indexes_Not_In_Use */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT o.name ,
        indexname = i.name ,
        i.index_id ,
        reads = user_seeks + user_scans + user_lookups ,
        writes = user_updates ,
        rows = ( SELECT SUM(p.rows)
                    FROM sys.partitions p
                    WHERE p.index_id = s.index_id
                        AND s.object_id = p.object_id
               ) ,
        CASE WHEN s.user_updates < 1 THEN 100
             ELSE 1.00 * ( s.user_seeks + s.user_scans + s.user_lookups ) / s.user_updates
        END AS reads_per_write ,
        'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(c.name) + '.' + QUOTENAME(OBJECT_NAME(s.object_id)) AS 'drop statement'
    FROM sys.dm_db_index_usage_stats s
        INNER JOIN sys.indexes i
            ON i.index_id = s.index_id
               AND s.object_id = i.object_id
        INNER JOIN sys.objects o
            ON s.object_id = o.object_id
        INNER JOIN sys.schemas c
            ON o.schema_id = c.schema_id
        INNER JOIN sys.[dm_db_partition_stats] AS ps ON ps.[object_id] = o.[object_id]
        INNER JOIN sys.partitions AS par on ps.partition_id=par.partition_id
    WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
        AND s.database_id = DB_ID()
        AND i.type_desc = 'nonclustered'
        AND i.is_primary_key = 0
        AND i.is_unique_constraint = 0
        AND ( SELECT SUM(p.rows)
                FROM sys.partitions p
                WHERE p.index_id = s.index_id
                    AND s.object_id = p.object_id
            ) > 10000
	ORDER BY reads_per_write;
    --ORDER BY reads;
GO


/* Missing indexes - from http://sqlserverpedia.com/wiki/Find_Missing_Indexes */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT o.name ,
        ( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans ) AS Impact ,
        avg_total_user_cost,
        avg_user_impact,
        ( user_seeks + user_scans ) AS seeks_and_scans,
        mid.equality_columns ,
        mid.inequality_columns ,
        mid.included_columns
    FROM
        sys.dm_db_missing_index_group_stats AS migs
        INNER JOIN sys.dm_db_missing_index_groups AS mig
            ON migs.group_handle = mig.index_group_handle
        INNER JOIN sys.dm_db_missing_index_details AS mid
            ON mig.index_handle = mid.index_handle
               AND mid.database_id = DB_ID()
        INNER JOIN sys.objects o WITH ( NOLOCK )
                                    ON mid.OBJECT_ID = o.OBJECT_ID
        INNER JOIN sys.[dm_db_partition_stats] AS ps ON ps.[object_id] = o.[object_id]
        INNER JOIN sys.partitions AS par on ps.partition_id=par.partition_id
    WHERE
		o.is_ms_shipped=0 and
        ( migs.group_handle IN ( SELECT TOP ( 500 ) group_handle
                                    FROM  sys.dm_db_missing_index_group_stats WITH ( NOLOCK )
                                    ORDER BY ( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans ) DESC ) )

    ORDER BY Impact DESC;
	--ORDER BY migs.avg_system_impact DESC;
GO


/*
Find misaligned partitioned indexes
This Copyright 2015 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*/
SELECT
    ISNULL(db_name(s.database_id),db_name()) AS DBName
    ,OBJECT_SCHEMA_NAME(i.object_id,DB_ID()) AS SchemaName
    ,o.name AS [Object_Name]
    ,i.name AS Index_name
    ,i.Type_Desc AS Type_Desc
    ,ds.name AS DataSpaceName
    ,ds.type_desc AS DataSpaceTypeDesc
    ,s.user_seeks
    ,s.user_scans
    ,s.user_lookups
    ,s.user_updates
    ,s.last_user_seek
    ,s.last_user_update
FROM sys.objects AS o
JOIN sys.indexes AS i ON o.object_id = i.object_id
JOIN sys.data_spaces ds ON ds.data_space_id = i.data_space_id
LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s ON i.object_id = s.object_id AND i.index_id = s.index_id AND s.database_id = DB_ID()
WHERE o.type = 'u'
AND i.type IN (1, 2)
AND o.object_id in
(
	SELECT a.object_id from
		(SELECT ob.object_id, ds.type_desc from sys.objects ob
        JOIN sys.indexes ind on ind.object_id = ob.object_id
        JOIN sys.data_spaces ds on ds.data_space_id = ind.data_space_id
		GROUP BY ob.object_id, ds.type_desc ) a
    GROUP BY a.object_id
    HAVING COUNT (*) > 1
						      )
ORDER BY [Object_Name] DESC;
GO


/* Find duplicate indexes
From Adam Machanic */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT t.name AS tableName ,
        p.*
    FROM sys.tables AS t
        INNER JOIN sys.indexes AS i1
            ON i1.object_id = t.object_id
        CROSS APPLY ( SELECT TOP 1 *
                        FROM sys.indexes AS i
                        WHERE i.object_id = i1.object_id
                            AND i.index_id > i1.index_id
                            AND i.type_desc <> 'xml'
							AND i.is_disabled = 0
                        ORDER BY i.index_id
                    ) AS i2
        CROSS APPLY ( SELECT MIN(a.index_id) AS ind1 ,
                            MIN(b.index_id) AS ind2
                        FROM ( SELECT ic.*
                                FROM sys.index_columns ic
                                WHERE ic.object_id = i1.object_id
                                    AND ic.index_id = i1.index_id
                                    AND ic.is_included_column = 0
                             ) AS a
                            FULL OUTER JOIN ( SELECT *
                                                FROM sys.index_columns AS ic
                                                WHERE ic.object_id = i2.object_id
                                                    AND ic.index_id = i2.index_id
                                                    AND ic.is_included_column = 0
                                            ) AS b
                                ON a.index_column_id = b.index_column_id
                                   AND a.column_id = b.column_id
                                   AND a.key_ordinal = b.key_ordinal
                        HAVING COUNT(CASE WHEN a.index_id IS NULL THEN 1
                                     END) = 0
                            AND COUNT(CASE WHEN b.index_id IS NULL THEN 1
                                      END) = 0
                            AND COUNT(a.index_id) = COUNT(b.index_id)
                    ) AS p
    WHERE i1.type_desc <> 'xml';
GO

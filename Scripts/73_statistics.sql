/******************************************
Copyright 2015 Brent Ozar PLF, LLC (DBA Brent Ozar Unlimited)
*******************************************/

/*  Script:         73_statistics.sql 

    Run as a:       F5 (FIRE AWAY!)

    Impact:         LIGHT (Will not block -- fire away!)

    Contains:       Database level information about statistics			

    Description:    See above

*/

SET NOCOUNT ON;	

SELECT  DISTINCT
        OBJECT_NAME([s].[object_id]) AS [table_name] ,
        ISNULL([i].[name], 'System Statistic') AS [index_name] ,
        [c].[name] AS [column_name] ,
        [s].[name] AS [statistics_name] ,
        [ddsp].[last_updated] AS [last_statistics_update] ,
        DATEDIFF(DAY, [ddsp].[last_updated], SYSDATETIME()) AS [days_since_last_stats_update],
		[ddsp].[rows] ,
        [ddsp].[rows_sampled] ,
        CAST([ddsp].[rows_sampled] / ( 1. * [ddsp].[rows] ) * 100 AS DECIMAL(18,1)) AS [percent_sampled] ,
        [ddsp].[steps] AS [histogram_steps] ,
        [ddsp].[modification_counter] ,
        CASE WHEN [ddsp].[modification_counter] > 0
             THEN CAST([ddsp].[modification_counter] / ( 1. * [ddsp].[rows] ) * 100 AS DECIMAL(18, 1))
             ELSE [ddsp].[modification_counter]
        END AS [percent_modifications] ,
        CASE WHEN [ddsp].[rows] < 500 THEN 500
             ELSE CAST(( [ddsp].[rows] * .20 ) + 500 AS INT)
        END AS [modifications_before_auto_update] ,
		ISNULL(i.[type_desc], 'System Statistic - N/A') AS [index_type_desc],
        CASE [c].[is_identity]
          WHEN 0 THEN 'Not Identity'
          WHEN 1 THEN 'Identity'
          ELSE 'System Statistic - N/A'
        END AS [is_identity] ,
        CASE [c].[is_computed]
          WHEN 0 THEN 'Not Computed'
          WHEN 1 THEN 'Computed'
          ELSE 'System Statistic - N/A'
        END AS [is_computed] ,
        CASE [i].[is_unique]
          WHEN 0 THEN 'Not Unique'
          WHEN 1 THEN 'Unique'
          ELSE 'System Statistic - N/A'
        END AS [is_unique] ,
        CASE [i].[is_primary_key]
          WHEN 0 THEN 'Not Primary Key'
          WHEN 1 THEN 'Primary Key'
          ELSE 'System Statistic - N/A'
        END AS [is_primary_key] ,
        CASE [i].[is_unique_constraint]
          WHEN 0 THEN 'Not Unique Constraint'
          WHEN 1 THEN 'Unique COnstraint'
          ELSE 'System Statistic - N/A'
        END AS [is_unique_constraint] ,
        [par].[data_compression_desc] ,
        [obj].[create_date] AS [table_create_date] ,
        [obj].[modify_date] AS [table_modify_date]
FROM    [sys].[stats] AS [s]
LEFT JOIN [sys].[indexes] AS [i]
ON      [i].[object_id] = [s].[object_id]
        AND [i].[index_id] = [s].[stats_id]
CROSS APPLY [sys].[dm_db_stats_properties]([s].[object_id], [s].[stats_id]) AS [ddsp]
JOIN    [sys].[stats_columns] [sc]
ON      [sc].[object_id] = [s].[object_id]
        AND [sc].[stats_id] = [s].[stats_id]
JOIN    [sys].[columns] [c]
ON      [c].[object_id] = [sc].[object_id]
        AND [c].[column_id] = [sc].[column_id]
JOIN    [sys].[partitions] [par]
ON      [par].[object_id] = [s].[object_id]
JOIN    [sys].[objects] [obj]
ON      [par].[object_id] = [obj].[object_id]
WHERE   OBJECTPROPERTY([s].[object_id], 'IsUserTable') = 1
ORDER BY [table_name] ,
        [statistics_name];

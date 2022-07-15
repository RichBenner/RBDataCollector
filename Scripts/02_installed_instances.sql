IF OBJECT_ID('tempdb..#Instance') IS NOT NULL DROP TABLE #Instances;
CREATE TABLE #Instance (InstanceNum nvarchar(100), InstanceName nvarchar(255), Data nvarchar(max))

INSERT INTO #Instance (InstanceNum, InstanceName, Data)
EXEC master.sys.xp_regread @rootkey = 'HKEY_LOCAL_MACHINE',
@key = 'SOFTWARE\Microsoft\Microsoft SQL Server',
@value_name = 'InstalledInstances'

SELECT InstanceNum, InstanceName FROM #Instance 
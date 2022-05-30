$sqlLinkedServers = "select srvname from sys.sysservers s where CHARINDEX('.',srvname) <> 0"
$dbaDatabase = 'DBA_Admin';

$linkedServers = Invoke-DbaQuery -SqlInstance 172.31.25.106 -Query $sqlLinkedServers -SqlCredential $personalCredential | Select-Object -ExpandProperty srvname;

cls
$SpaceRequirement = @()
$sqlSpaceRequirement = @"
declare @_tbl_disk_drive table (drive varchar(1), mb_free bigint);
declare @host_name varchar(125);
declare @database_name varchar(125);
declare @object_name varchar(255);
declare @days_threshold tinyint = 60;

insert @_tbl_disk_drive (drive, mb_free)
exec xp_fixeddrives;

select @host_name = host_name from $dbaDatabase.dbo.instance_details;
set @object_name = (case when @@SERVICENAME = 'MSSQLSERVER' then 'SQLServer' else 'MSSQL$'+@@SERVICENAME end);
set @database_name = '$dbaDatabase'

;with t_size_start as (
	select top 1 'InitialSize' as QueryData, 
			collection_time_utc = case when datediff(day,collection_time_utc,GETUTCDATE()) >= 365  then (select create_date from $dbaDatabase.sys.tables where name = 'performance_counters') else collection_time_utc end, value
	from $dbaDatabase.dbo.performance_counters pc
	where pc.host_name = @host_name
	and pc.object = (@object_name+':Databases') and pc.counter in ('Data File(s) Size (KB)')
		 and pc.instance = @database_name
	order by collection_time_utc asc
)
, t_size_latest as (
	select top 1 'CurrentSize' as QueryData, *
	from $dbaDatabase.dbo.performance_counters pc
	where pc.host_name = @host_name
	and pc.object = (@object_name+':Databases') and pc.counter in ('Data File(s) Size (KB)')
		 and pc.instance = @database_name
	order by collection_time_utc desc
)
, t_disk_drive_size as (
	select [server_ip] = CONNECTIONPROPERTY('local_net_address'), 
			server_name = SERVERPROPERTY('ServerName'),
			drive = drive+':\',
			mb_free, free_space_gb = convert(numeric(20,2),mb_free/1024.0)
	from @_tbl_disk_drive d where d.drive in 
					(select [drive] = left(physical_name,1)
					from sys.master_files mf
					where mf.database_id = db_id('$dbaDatabase')
					and mf.type_desc = 'ROWS')
)
select	QueryData = 'Size-Estimate', [server_ip], server_name, drive, free_space_gb,
		start__collection_time_utc = i.collection_time_utc
		,[start__size_gb] = i.value/1024/1024 
		,[current__size_gb] = l.value/1024/1024
		,[days-of-growth] = DATEDIFF(day,i.collection_time_utc, l.collection_time_utc)
		,[size_gb-of-growth] = (l.value-i.value)/1024.0/1024.0
		,[total_gb-in-threshold-Days] = (((l.value-i.value)/1024.0/1024.0)/(DATEDIFF(day,i.collection_time_utc, l.collection_time_utc)))*60
		,[space_gb-2-add] = convert(numeric(20,2),(((l.value-i.value)/1024.0/1024.0)/(DATEDIFF(day,i.collection_time_utc, l.collection_time_utc)))*(@days_threshold-DATEDIFF(day,i.collection_time_utc, l.collection_time_utc)))
from t_size_latest l, t_size_start i, t_disk_drive_size;
"@

$failedServers = @()
foreach($srv in $linkedServers) {
    try {
        $SpaceRequirement += Invoke-DbaQuery -SqlInstance $srv -Query $sqlSpaceRequirement -SqlCredential $personalCredential -EnableException
    }
    catch {
        $errMessage = $_;
        "Failed for server [$srv] => `n'$($errMessage.Exception.Message)'" | Write-Host -ForegroundColor Red
        $failedServers += $srv
    }

}

$failedServers | ogv -Title "Failed Servers"
$SpaceRequirement | ogv -Title "Space of Servers"
$SpaceRequirement | Export-Excel -Path $env:USERPROFILE\disk-space-details.xlsx
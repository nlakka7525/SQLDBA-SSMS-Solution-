use DBA_Admin
go

declare @start_time datetime = '2022-05-24 09:00:00.000'
declare @end_time datetime = '2022-05-24 11:00:00.000'

select rc.username, rc.client_app_name, sum(cpu_time/1000000)/60 as cpu_time_minutes, 
		convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024) as logical_reads_gb, convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)) as logical_reads_mb_avg,
		sum(rc.duration_seconds)/60 as duration_minutes, sum(rc.duration_seconds)/count(*) as duration_seconds_avg
		,count(*) as counts , sum(cpu_time/1000000)/count(*) as cpu_time_seconds_avg
from dbo.resource_consumption rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
group by rc.username, rc.client_app_name
order by logical_reads_mb_avg desc, logical_reads_gb desc, duration_minutes desc, cpu_time_minutes desc
-- grafana, grafana
go

use DBA_Admin
go

declare @start_time datetime = '2022-05-24 07:00:00.000'
declare @end_time datetime = '2022-05-24 11:00:00.000'

select rc.username, rc.client_app_name, sum(cpu_time/1000000)/60 as cpu_time_minutes, 
		sum(logical_reads)*8.0/1024/1024 as logical_reads_gb, sum(logical_reads)*8.0/1024/count(*) as logical_reads_mb_avg,
		sum(rc.duration_seconds)/60 as duration_minutes, sum(rc.duration_seconds)/count(*) as duration_seconds_avg
		,count(*) as counts , sum(cpu_time/1000000)/count(*) as cpu_time_seconds_avg
from dbo.resource_consumption rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
group by rc.username, rc.client_app_name
order by cpu_time_minutes desc, logical_reads_gb desc, duration_minutes desc
-- grafana, grafana
go


/*
exec proc_sbClient_Ipartner @Sdate=N'2022-05-23',@segments=N'ACDLFO',@subbrokcode=N'SMBMA',@Edate=N'2022-05-23'
*/

declare @start_time datetime = '2022-05-24 12:00:00.000'
declare @end_time datetime = '2022-05-24 13:00:00.000'
select *
from dbo.WhoIsActive w
where w.collection_time between @start_time and @end_time
and session_id = 168


use DBA_Admin
go

declare @start_time datetime = '2022-05-24 09:00:00.000'
declare @end_time datetime = '2022-05-24 11:00:00.000'

select *
from dbo.resource_consumption rc
where (	rc.start_time between @start_time and @end_time
		or rc.event_time between @start_time and @end_time)
--and rc.username = '' and rc.client_app_name = ''
order by logical_reads desc
go

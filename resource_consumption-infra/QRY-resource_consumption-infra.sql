use DBA_Admin
go

declare @start_time datetime = '2022-07-11 00:00:00'
declare @end_time datetime = '2022-07-19 00:00:00'

select	[grouping-key] = (case when client_app_name like 'SQL Job = %' then client_app_name else left(sql_text,25) end), 
		sum(cpu_time/1000000)/60 as cpu_time_minutes, 
		convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024) as logical_reads_gb, convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)) as logical_reads_mb_avg,
		convert(numeric(20,2),sum(writes)*8.0/1024/1024) as writes_gb, convert(numeric(20,2),sum(writes)*8.0/1024/count(*)) as writes_mb_avg,
		sum(rc.duration_seconds)/60 as duration_minutes, sum(rc.duration_seconds)/count(*) as duration_seconds_avg
		,count(*) as counts , sum(cpu_time/1000000)/count(*) as cpu_time_seconds_avg
from dbo.resource_consumption rc
where (	rc.start_time between @start_time and @end_time or rc.event_time between @start_time and @end_time )
group by (case when client_app_name like 'SQL Job = %' then client_app_name else left(sql_text,25) end)
order by writes_gb desc,  writes_mb_avg desc
go

--select top 100 *
--from dbo.resource_consumption
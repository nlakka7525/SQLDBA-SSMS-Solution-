use DBA_Admin
go

declare @start_time datetime = '2022-07-11 00:00:00'
declare @end_time datetime = '2022-07-15 23:59:59'

select top 100 master.dbo.sql_signature(sql_text) as sql_signature, *
from dbo.resource_consumption rc
where (	rc.start_time between @start_time and @end_time or rc.event_time between @start_time and @end_time )
go

/*
exec sp_readrequest  @receive_timeout=600000
exec sp_readrequest  @receive_timeout=##
*/

declare @start_time datetime = '2022-07-11 00:00:00'
declare @end_time datetime = '2022-07-15 23:59:59'

;with cte_group as (
	select	[grouping-key] = (case when client_app_name like 'SQL Job = %' then client_app_name else left(sql_text,30) end), 
			[cpu_time_minutes] = sum(cpu_time/1000000)/60,
			[cpu_time_seconds_avg] = sum(cpu_time/1000000)/count(*),
			[logical_reads_gb] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024), 
			[logical_reads_gb_avg] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024/count(*)),
			[logical_reads_mb_avg] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)),
			[writes_gb] = convert(numeric(20,2),sum(writes)*8.0/1024/1024),
			[writes_mb] = convert(numeric(20,2),sum(writes)*8.0/1024),
			[writes_gb_avg] = convert(numeric(20,2),sum(writes)*8.0/1024/1024/count(*)),
			[writes_mb_avg] = convert(numeric(20,2),sum(writes)*8.0/1024/count(*)),
			[duration_minutes] = sum(rc.duration_seconds)/60,
			[duration_minutes_avg] = sum(rc.duration_seconds)/60/count(*),
			[duration_seconds_avg] = sum(rc.duration_seconds)/count(*),
			[counts] = count(*)
	from DBA_Admin.dbo.resource_consumption rc
	where (	rc.start_time between @start_time and @end_time or rc.event_time between @start_time and @end_time )
	group by (case when client_app_name like 'SQL Job = %' then client_app_name else left(sql_text,30) end)
)
select *
into DBA_Admin.dbo.rc_july_11_to_15
from cte_group ct
--order by [logical_reads_gb] desc
--select *
--from dbo.resource_consumption rc
--where (	rc.start_time between @start_time and @end_time or rc.event_time between @start_time and @end_time )
--order by writes_gb desc,  writes_mb_avg desc
go

-- drop table DBA_Admin.dbo.rc_july_11_to_15
select top 10 *
from DBA_Admin.dbo.rc_july_11_to_15
where [grouping-key] not like '(dba) %'
order by [logical_reads_mb] desc
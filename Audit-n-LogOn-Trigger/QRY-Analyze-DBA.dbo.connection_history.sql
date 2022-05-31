/*
exec sp_cycle_errorlog
go 10
*/

select *
from master.dbo.connection_limit_config;
go

select convert(date,collection_time) as [date], DATEPART(hour,collection_time) as [hour],
		login_name, program_name, host_name, count(1) as connections_counts
from DBA.dbo.connection_history
where collection_time between DATEADD(hour,-4,SYSDATETIME()) and SYSDATETIME()
group by convert(date,collection_time), DATEPART(hour,collection_time),
		login_name, program_name, host_name

--exec sp_WhoIsActive

--truncate table DBA.dbo.connection_history
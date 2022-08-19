/*
	select [memory_gb] = der.granted_query_memory*8.0/1024/1024, 
			[--kill query--] = 'kill '+convert(varchar,der.session_id)+char(10)
			,[--find-query--] = 'dbcc inputbuffer('+convert(varchar,der.session_id)+')'
			,[session_tran_count] = des.open_transaction_count 
			,[request_tran_count] = der.open_transaction_count
			,[elapsed_time] = convert(varchar,getdate()-der.start_time,108)
			,der.session_id, der.status, der.command
			,[db_name] = db_name(der.database_id)
			,der.blocking_session_id, der.wait_type, [wait_time] = dateadd(ms,wait_time,'1900-01-01 00:00:00.000')
			,der.wait_resource, der.percent_complete, der.cpu_time, der.total_elapsed_time
			,der.logical_reads, der.writes, der.row_count, query_hash, dop, parallel_worker_count
	from sys.dm_exec_requests der join sys.dm_exec_sessions des
		on des.session_id = der.session_id
	where der.granted_query_memory*8.0/1024/1024 >= 2
	--and der.open_transaction_count = 0 and des.open_transaction_count = 0
	order by memory_gb desc

	
*/

declare @kill_string nvarchar(200);
declare cur_connections cursor static local for 
				select --[memory_gb] = der.granted_query_memory*8.0/1024/1024, 
						[--kill query--] = 'kill '+convert(varchar,der.session_id)+char(10)+'go'+char(10)
						--,des.open_transaction_count ,der.open_transaction_count, der.*
				from sys.dm_exec_requests der join sys.dm_exec_sessions des
					on des.session_id = der.session_id
				where der.granted_query_memory*8.0/1024/1024 >= 2
				and der.open_transaction_count = 0 and des.open_transaction_count = 0;

open cur_connections;
fetch next from cur_connections into @kill_string

while @@FETCH_STATUS = 0
begin
	begin try
		print @kill_string
		exec (@kill_string);
	end try
	begin catch
	end catch
	fetch next from cur_connections into @kill_string
end

close cur_connections
deallocate cur_connections
go

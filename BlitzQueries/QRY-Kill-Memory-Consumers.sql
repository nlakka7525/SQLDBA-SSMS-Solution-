/*
	select [memory_gb] = der.granted_query_memory*8.0/1024/1024, 
			[--kill query--] = 'kill '+convert(varchar,der.session_id)+char(10)+'go'+char(10)
			,des.open_transaction_count ,der.open_transaction_count, der.*
	from sys.dm_exec_requests der join sys.dm_exec_sessions des
		on des.session_id = der.session_id
	where der.granted_query_memory*8.0/1024/1024 >= 2
	and der.open_transaction_count = 0 and des.open_transaction_count = 0;
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

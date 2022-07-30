use DBA_Admin
go

--;with xmlnamespaces (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
;with xmlnamespaces ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' as qp),
t_queries as (
	select	* 
			,[sql_handle] = additional_info.value('(/additional_info/sql_handle)[1]','varchar(500)')
			--,[plan_handle] = additional_info.value('(/additional_info/plan_handle)[1]','varchar(500)')
			,[command_type] = additional_info.value('(/additional_info/command_type)[1]','varchar(50)')
			,[query_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryHash','varchar(100)')
			,[query_plan_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryPlanHash','varchar(100)')
			,[NonParallelPlanReason] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple/*:QueryPlan)[1]/@NonParallelPlanReason','varchar(200)')
			--,[optimization_level] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@StatementOptmLevel', 'sysname')
			--,[early_abart_reason] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@StatementOptmEarlyAbortReason', 'sysname')
			--,[CardinalityEstimationModelVersion] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@CardinalityEstimationModelVersion','int')
			,[used_memory_mb] = convert(numeric(20,2),convert(bigint,replace(used_memory,',',''))*8.0/1024)
	from dbo.WhoIsActive w
	where w.collection_time between dateadd(day,-2,getdate()) and getdate()
	and w.login_name = 'Lab\SQLServices'
	and w.database_name = 'NSEFO'
	and w.program_name like 'SQL Job = NSE FUTURES AUTO PROCESS SETTLEMENT%'
	--and w.blocking_session_id is null
	--and DATEDIFF(minute,w.start_time, w.collection_time) > 30
)
,top_queries as (
	select *
	from t_queries w
	--where [used_memory_mb] > 500
)
select top 1000 [collection_time], [start_time], [dd hh:mm:ss.mss],
		[query_identifier] = left((case when [query_hash] is not null then [query_hash] else [sql_handle] end),20),
		[query_hash_count] = COUNT(session_id)over(partition by (case when [query_hash] is not null then [query_hash] else [sql_handle] end), convert(varchar(max), sql_command)),		
		[session_id], [blocking_session_id], [command_type], [sql_text], [CPU], [used_memory_mb], [open_tran_count], 
		[status], [wait_info], [query_hash], [sql_command], [blocked_session_count], [reads], [writes], [tempdb_allocations], [tasks], [query_plan], 
		[query_plan_hash], [NonParallelPlanReason], [host_name], [additional_info], [program_name], [login_name], [database_name], [duration_minutes]		
from top_queries
--order by [duration_minutes] desc
--order by [collection_time], session_id, [start_time]
order by [collection_time], [blocked_session_count] desc, session_id, [start_time]
go

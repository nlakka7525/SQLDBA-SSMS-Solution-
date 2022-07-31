USE [DBA]
go

-- Find long running statements of session
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
	where w.collection_time >= '2022-07-29 18:12' and w.collection_time <= '2022-07-29 19:45'
	and w.database_name = 'DBA' and w.login_name = 'LAB\SQLServices' and w.program_name = 'SQLCMD'
	and w.session_id = 134
)
,t_capture_interval as (
	select [capture_interval_minutes] = datediff(minute,min(collection_time),max(collection_time))*1.0/count(*) from t_queries
)
,top_queries as (
	select	*,
			[query_identifier] = left((case when [query_hash] is not null then [query_hash] else [sql_handle] end),20),
			[query_hash_count] = COUNT(session_id)over(partition by (case when [query_hash] is not null then [query_hash] else [sql_handle] end), isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command])))
	from t_queries w
	--where [used_memory_mb] > 500
)
select top 1000 [collection_time], [dd hh:mm:ss.mss], [query_identifier],
		[qry_time_min(~)] = ceiling([query_hash_count]*[capture_interval_minutes]),		
		[query_hash_count], [session_id], [blocking_session_id], [command_type], [sql_text], [CPU], [used_memory_mb], [open_tran_count], 
		[status], [wait_info], [query_hash], [sql_command], [blocked_session_count], [reads], [writes], [tempdb_allocations], [tasks], [query_plan], 
		[query_plan_hash], [NonParallelPlanReason], [host_name], [additional_info], [program_name], [login_name], [database_name], [duration_minutes],
		[batch_start_time] = [start_time]
from top_queries,t_capture_interval
--order by [duration_minutes] desc
--order by [collection_time], session_id, [start_time]
order by [collection_time], [blocked_session_count] desc, session_id, [start_time]
go
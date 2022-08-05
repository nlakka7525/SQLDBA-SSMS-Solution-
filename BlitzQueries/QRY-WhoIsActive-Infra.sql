USE [DBA_Admin]
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
	where w.collection_time >= dateadd(day,-7,getdate()) and w.collection_time <= getdate()
	and w.database_name = 'remisior'
	--and (	convert(varchar(max),w.sql_text) like '%[[. ]tbl_nsefo_sharing_trade[!] ]%' escape '!' )
	--and duration_minutes >= 5
	--dbo.Tbl_Kyc_CloudStage_ClientInfo.IX_Tbl_Kyc_CloudStage_ClientInfo_PartyCode_CodeActivationDate (43)
	--and convert(varchar(max),w.query_plan) like '%Database="![remisior!]" Schema="![dbo!]" Table="![AddBrkTrnx!]"%' escape '!'
	--and convert(varchar(max),w.query_plan) like '%Database="![remisior!]" Schema="![dbo!]" Table="![AddBrkTrnx!]" Index="![IX_updt_cltcode!]"%' escape '!'
)
,t_capture_interval as (
	select [capture_interval_sec] = DATEDIFF(SECOND,snap1.collection_time_min, collection_time_snap2) 
	from (select min(collection_time) as collection_time_min from t_queries) snap1
	outer apply (select min(s2.collection_time) as collection_time_snap2 from t_queries s2 where s2.collection_time > snap1.collection_time_min) snap2
)
,top_queries as (
	select	*,
			[query_identifier] = left((case when [query_hash] is not null then [query_hash] else [sql_handle] end),20),
			--[query_hash_count] = COUNT(session_id)over(partition by session_id, program_name, login_name, (case when [query_hash] is not null then [query_hash] else [sql_handle] end), isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command])))
			[query_hash_count] = COUNT(session_id)over(partition by (case when [query_hash] is not null then [query_hash] 
																		  when [sql_handle] is not null then [sql_handle]
																		  else isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command]))
																		  end))
	from t_queries w
	--where [used_memory_mb] > 500
)
select top 1000 [collection_time], [dd hh:mm:ss.mss], [query_identifier],[capture_interval_sec],
		[qry_time_min(~)] = ceiling([query_hash_count]*[capture_interval_sec]/60),		
		[query_hash_count], [session_id], [blocking_session_id], [command_type], [sql_text], [query_hash], [sql_handle], [CPU], [used_memory_mb], [open_tran_count], 
		[status], [wait_info], [sql_command], [blocked_session_count], [reads], [writes], [tempdb_allocations], [tasks], [query_plan], 
		[query_plan_hash], [NonParallelPlanReason], [host_name], [additional_info], [program_name], [login_name], [database_name], [duration_minutes],
		[batch_start_time] = [start_time]
from top_queries,t_capture_interval
where command_type not in ('ALTER INDEX')
--where [query_identifier] not in ('0xA1A533089E2AFBEB')
--order by [duration_minutes] desc
--order by [collection_time], session_id, [start_time]
--order by [collection_time], [blocked_session_count] desc, session_id, [start_time]
order by [collection_time]

go
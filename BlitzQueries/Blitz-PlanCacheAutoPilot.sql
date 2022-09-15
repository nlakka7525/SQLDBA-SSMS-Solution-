use DBA
go

--truncate table dbo.PlanCacheAutopilot

select top 100 *
from dbo.PlanCacheAutopilot pca
where pca.plan_generation_num > 10 order by pca.plan_generation_num desc /* Plans getting recompiled */
go

/* Get top queries by their Occurrences */
select top 200 query_hash, count(*) as recs, count(distinct query_plan_hash) as plan_count
from dbo.PlanCacheAutopilot pca
group by query_hash
having count(distinct query_plan_hash) > 1
order by plan_count desc, recs desc
go

/* Get Details of Queries by QueryHash */
select *
from dbo.PlanCacheAutopilot pca
where pca.query_hash in (0x81628FB507FEDD01,0x8E2C5C53F48965AB)
order by query_hash, query_plan_hash
go

;with xmlnamespaces ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' as qp),
t_whoisactive as (
	select * , [query_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryHash','varchar(100)')
	from dbo.WhoIsActive w
	where query_plan is not null
	
)
select top 10 *
from t_whoisactive w
where w.query_hash = 0xCB7D3EAB23F4CF0E
--0x9EC83C15092E7A99
order by collection_time desc
option(fast 10)
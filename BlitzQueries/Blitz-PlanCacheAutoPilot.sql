use DBA
go

select top 100 *
from dbo.PlanCacheAutopilot
go

/* Get top queries by their Occurrences */
select top 200 query_hash, count(*) as recs, count(distinct query_plan_hash) as plan_count
from dbo.PlanCacheAutopilot pca
group by query_hash
order by recs desc, plan_count desc
go

/* Get Details of Queries by QueryHash */
select *
from dbo.PlanCacheAutopilot pca
where pca.query_hash in (0x754FE9041849493F,0x5CD2446FAFC7F00D)
order by query_hash, query_plan_hash
go

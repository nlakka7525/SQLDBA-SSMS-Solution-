EXEC tempdb..sp_BlitzCache @Help = 1
EXEC tempdb..sp_BlitzCache @ExpertMode = 1, @ExportToExcel = 1

--	https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit#common-sp_blitzcache-parameters
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'reads', @IgnoreSystemDBs = 0, -- queries doing lot of reads
					@OutputDatabaseName = 'DBA_Admin', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache'
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'writes' -- queries with high writes
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'memory grant' -- Queries using maximum memory grant
exec master..sp_BlitzCache @SortOrder = 'spills', @Top = 30 -- Queries spilling to disk
exec master..sp_BlitzCache @SortOrder = 'unused grant', @Top = 30 -- Queries asking for huge memory grant, but simply wasting it.

exec master..sp_BlitzCache @SortOrder = 'CPU', @Top = 30 -- Queries with High executions
					,@OutputDatabaseName = 'DBA_Admin', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_CPU_20230321'
exec master..sp_BlitzCache @SortOrder = 'xpm', @Top = 30 -- Queries with High executions
					,@OutputDatabaseName = 'DBA_Admin', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_xpm_20230321'
exec master..sp_BlitzCache @SortOrder = 'recent compilations', @Top = 2000, @SkipAnalysis = 1 -- Recently compiled queries that may need parametization
					,@OutputDatabaseName = 'DBA_Admin', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_RecentCompilations_20230321'

select top 500 * from DBA_Admin.dbo.BlitzCache

--	Analyze using Procedure Name
exec master..sp_BlitzCache @StoredProcName = 'usp_rm_get_source_logo_gaps_Ajay'
exec master..sp_BlitzCache @StoredProcName = 'usp_rm_get_source_logo_gaps'

--	Analyze using Query Hash in case SQL Code is not procedure
exec tempdb..sp_BlitzCache @OnlyQueryHashes = '0x998533A642130191'

/*
USP_Program_DuplicateCheck 
USP_Program_IntegratedSearch_ProgramCPR   
USP_Get_Program_DeepLoad 
usp_schres_autofill_control
*/

use master;
go

select * 
from sys.dm_server_services
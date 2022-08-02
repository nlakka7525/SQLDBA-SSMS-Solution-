EXEC tempdb..sp_BlitzCache @Help = 1
EXEC tempdb..sp_BlitzCache @ExpertMode = 1, @ExportToExcel = 1

--	https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit#common-sp_blitzcache-parameters
EXEC master..sp_BlitzCache @Top = 20, @SortOrder = 'reads' -- queries doing lot of reads
EXEC master..sp_BlitzCache @Top = 20, @SortOrder = 'CPU' -- queries consuming high cpu time
EXEC master..sp_BlitzCache @Top = 20, @SortOrder = 'writes' -- queries with high writes
EXEC master..sp_BlitzCache @Top = 20, @SortOrder = 'memory grant' -- Queries using maximum memory grant
exec master..sp_BlitzCache @SortOrder = 'spills', @Top = 20 -- Queries spilling to disk
exec master..sp_BlitzCache @SortOrder = 'unused grant', @Top = 20 -- Queries asking for huge memory grant, but simply wasting it.

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
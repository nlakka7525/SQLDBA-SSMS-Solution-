-- Commands to Run on SQL Server (Each Monitored Instance)

USE [master]
GO

-- drop table [dbo].[connection_limit_config]
CREATE TABLE [dbo].[connection_limit_config]
(
	[login_name] sysname not null,
	[program_name] sysname not null,
	[host_name] sysname not null,
	[limit] smallint,
	[reference] varchar(255) null,
	constraint pk_connection_limit_config primary key ([login_name],[program_name],[host_name])
)
GO
GRANT SELECT ON [dbo].[connection_limit_config] TO [public]
GO

-- drop table [dbo].[connection_limit_config_history]
CREATE TABLE [dbo].[connection_limit_config_history]
(
	[id] int IDENTITY(1,1) NOT NULL,
	[login_name] sysname not null,
	[program_name] sysname    NOT NULL,
	[host_name] sysname not null,
	[limit] smallint    NULL,
	[collection_time] datetime2 NOT NULL,
	[changed_by] sysname not NULL,
	[change_type] varchar(1) NOT NULL,
	[reference] varchar(255) NULL,
	constraint pk_connection_limit_config_history primary key nonclustered ([collection_time], [login_name], [id])
)
GO
GRANT SELECT ON [dbo].[connection_limit_config_history] TO [public]
GO
--CREATE NONCLUSTERED INDEX [ix_collection_time_login_name] on [dbo].[connection_limit_config_history] ([collection_time],[login_name])
GO

-- drop trigger if exists [tgr_delete_connection_limit_config]
CREATE TRIGGER [dbo].[tgr_delete_connection_limit_config]
	ON [dbo].[connection_limit_config]
FOR DELETE
AS
	INSERT INTO [dbo].[connection_limit_config_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	deleted.[login_name],
			deleted.[program_name],
			deleted.[host_name],
			deleted.[limit],
			deleted.[reference],
			sysdatetime(),
			SUSER_NAME(),
			'D'
	  FROM deleted
GO

-- drop trigger if exists [tgr_insert_connection_limit_config]
CREATE TRIGGER [dbo].[tgr_insert_connection_limit_config]
	ON [dbo].[connection_limit_config]
FOR INSERT
AS
	INSERT INTO [dbo].[connection_limit_config_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	inserted.[login_name],
			inserted.[program_name],
			inserted.[host_name],
			inserted.[limit],
			inserted.[reference],
			sysdatetime(),
			SUSER_NAME(),
			'I'
	FROM inserted
GO

-- drop trigger if exists [tgr_update_connection_limit_config]
CREATE TRIGGER [dbo].[tgr_update_connection_limit_config]
	ON [dbo].[connection_limit_config]
FOR UPDATE
AS
INSERT INTO [dbo].[connection_limit_config_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	inserted.[login_name],
			inserted.[program_name],
			inserted.[host_name],
			deleted.[limit],
			deleted.[reference],
			sysdatetime(),
			SUSER_NAME(),
			'U'
  FROM inserted full outer join deleted
	on inserted.login_name = deleted.login_name
	and inserted.program_name = deleted.program_name
	and inserted.host_name = deleted.host_name
GO

-- Insert Default Value
INSERT INTO [dbo].[connection_limit_config] 
([login_name], [program_name], [host_name], [limit])
SELECT [login_name] = '*', [program_name] = '*', [host_name] = '*', [limit] = 300;

select * from [dbo].[connection_limit_config]
GO

-- =========================================================================================================
-- =========================================================================================================

USE [DBA]
GO

CREATE TABLE [dbo].[connection_history]
(
	[session_id] [smallint] NOT NULL,
	[host_process_id] [int] NULL,
	[login_time] [datetime] NULL,
	[host_name] [varchar](128) NULL,
	[client_net_address] [varchar](48) NULL,
	[program_name] [varchar](128) NULL,
	[client_version] [int] NULL,
	[login_name] [varchar](128) NULL,
	[client_interface_name] [varchar](32) NULL,
	[auth_scheme] [nvarchar](40) NULL,
	[collection_time] [datetime2] NOT NULL default (SYSDATETIME()),
	[is_pooled] [bit] NULL
) on ps_dba([collection_time])
GO

create index ci_connection_history on [dbo].[connection_history] 
	([collection_time], [login_name], [program_name]) on ps_dba([collection_time])
go

-- =========================================================================================================
--DISABLE Trigger [audit_login_events] ON ALL SERVER;  
--GO
-- =========================================================================================================
-- Login Trigger
USE [master]
GO

CREATE OR ALTER TRIGGER [audit_login_events] ON ALL SERVER 
FOR LOGON 
AS 
SET XACT_ABORT OFF
BEGIN
	-- Declare Variables
	declare @app_name sysname = APP_NAME();
	declare @login_name sysname = SUSER_NAME();
	declare @host_name sysname = host_name();
	declare @data xml;
	declare @ispooled bit;

	declare @engine_service_account sysname;
	declare @agent_service_account sysname;

	select @engine_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server (%)');
	select @agent_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server Agent (%)');

	--select [@app_name] = @app_name, [@login_name] = @login_name, [@host_name] = @host_name,	[@engine_service_account] = @engine_service_account, [@agent_service_account] = @agent_service_account;

	-- Determine whether the login should be excluded from tracking in DBA.dbo._hist_sysprocesses
    IF LOWER(@login_name) IN (@engine_service_account, @agent_service_account, 'sa','angeltrade\angeltrade_dba_team','.\sql','nt authority\system', LOWER(DEFAULT_DOMAIN()+'\'+CONVERT(nvarchar(128), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))+'$')) 
        RETURN ;
    IF @login_name LIKE N'%_sa'
		RETURN;
    IF ISNULL(DATABASEPROPERTYEX('DBA', 'Status'), 'N/A') <> 'ONLINE'
		RETURN;
	IF ConnectionProperty('net_transport') IN ('Named pipe','Shared memory')
		RETURN;

	-- Reject connections above threshold limit defined in master.dbo.connection_limit_config
	IF EXISTS (SELECT OBJECT_ID('master.dbo.connection_limit_config'))
	BEGIN
		DECLARE @connection_limit smallint,
				@connection_count smallint;
		DECLARE @config_login_name sysname;
		DECLARE @config_program_name sysname;
		DECLARE @config_host_name sysname;
		DECLARE @message varchar(5000);

		-- Find specific limit with all 3 parameters match
		SELECT @connection_limit = limit, @config_login_name = [login_name], @config_program_name = [program_name], @config_host_name = [host_name]
		FROM master.dbo.connection_limit_config WITH (NOLOCK)
		WHERE [login_name] = @login_name
		and [program_name] = isnull(@app_name,'*')
		and [host_name] = @host_name;

		-- If no specific limit is defined, use default
		IF (@connection_limit IS NULL)
		BEGIN
			SELECT @connection_limit = limit, @config_login_name = [login_name], @config_program_name = [program_name], @config_host_name = [host_name]
			FROM (
					SELECT	TOP 1 
							(case when [login_name] = @login_name then 200 else 0 end) +
							(case when [login_name] = '*' then 5 else 0 end) +
							(case when [program_name] = isnull(@app_name,'*') then 100 else 0 end) +
							(case when [program_name] = '*' then 5 else 0 end) +
							(case when [host_name] = @host_name then 100 else 0 end) +
							(case when [host_name] = '*' then 5 else 0 end) as [score], *
					FROM master.dbo.connection_limit_config WITH (NOLOCK)
					WHERE ([login_name] = @login_name  or [login_name] = '*')
					and ([program_name] = isnull(@app_name,'*') or [program_name] = '*')
					and ([host_name] = @host_name or [host_name] = '*')
					order by [score] desc
			) t_limit;					
		END;

		if @config_login_name = '*' and @config_program_name = '*' and @config_host_name = '*'
			select @connection_count = count(1)
			from sys.dm_exec_sessions es
			where  es.login_name = @login_name
		else
			select @connection_count = count(1)
			from sys.dm_exec_sessions es
			where (es.login_name = @login_name or @login_name = '*')
			and (es.program_name = @config_program_name or @config_program_name = '*')
			and (es.host_name = @config_host_name or @config_host_name = '*');

	  IF (@connection_count > @connection_limit)
	  BEGIN
		SET @message='Connection attempt by { login || program } = {{ ' + @login_name+' || '+@app_name+' }}' + ' from host ' + @host_name +' has been rejected due to breached concurrent connection limit (' + convert(varchar, @connection_count) + '>=' + convert(varchar, @connection_limit) + ').';
		RAISERROR (@message, 10, 1);
		ROLLBACK;
		RETURN;
	  END;
	END;

	-- Determine whether the connection is pooled
	SET @data = EVENTDATA()
    SET @ispooled = @data.value('(/EVENT_INSTANCE/IsPooled)[1]', 'bit');

	-- Try to log the information in DBA, but allow the login even if unsuccessful.
	BEGIN TRY
		INSERT INTO [DBA].[dbo].[connection_history]
		(session_id, host_process_id, login_time, host_name, client_net_address, program_name, client_version, login_name, client_interface_name, auth_scheme, is_pooled)
		SELECT	@@SPID,  
				des.host_process_id,     
				des.login_time,     
				des.host_name,     
				dec.client_net_address,     
				des.program_name,  
				des.client_version,
				@login_name,
				des.client_interface_name,  
				dec.auth_scheme,
				@ispooled 
		FROM	sys.dm_exec_sessions des
		JOIN	sys.dm_exec_connections dec ON des.session_id=dec.session_id AND des.session_id=@@SPID and dec.net_transport <> 'Session';
		REVERT;
	END TRY
	BEGIN CATCH
		--IF @@TRANCOUNT > 0 ROLLBACK;
		REVERT;
	END CATCH
END
GO

ENABLE TRIGGER [audit_login_events] ON ALL SERVER
GO

-- =========================================================================================================
-- =========================================================================================================

/*
SELECT * FROM master.dbo._connection_limit_config;
SELECT * FROM master.dbo.[_connection_limit_blocked];
--truncate table master.dbo.[_connection_limit_blocked]


set nocount on;

if OBJECT_ID('tempdb..#connection_limit_blocked') is not null
	drop table #connection_limit_blocked;
;with T_Connections as (
	select [program_name], count(*) as connection_count
	from sys.dm_exec_sessions
	where [program_name] is not null
	group by [program_name]
)
,T_Blocked_Entry as (
	--insert  master.dbo.[_connection_limit_blocked] ([program_name], connection_count, action_type, action_date)
	select [program_name], connection_count, coalesce(pl.limit, dl.limit) as limit,
			action_type = case when connection_count >= coalesce(pl.limit, dl.limit) then 'BLOCK'
								when connection_count >= coalesce(pl.limit, dl.limit)*0.8 then 'WARN'
								else NULL
								END, 
			action_date = GETDATE()
	--into #connection_limit_blocked
	from T_Connections as c
	outer apply (SELECT limit FROM master.dbo._connection_limit_config as l where l.[program_name] = c.[program_name] ) as pl
	outer apply (SELECT limit FROM master.dbo._connection_limit_config as d where d.[program_name] = 'default') as dl
)
select	*
into #connection_limit_blocked
from T_Blocked_Entry
where action_type is not null



-- insert new program
insert master.dbo.[_connection_limit_blocked] ([program_name], connection_count, action_type, action_date)
select [program_name], connection_count, action_type, action_date
from #connection_limit_blocked as d
where d.action_type is not null
	and not exists (select * from master.dbo.[_connection_limit_blocked] as b where b.[program_name] = d.[program_name])

-- update existing program
select d.[program_name], d.connection_count, d.action_type, d.action_date
from #connection_limit_blocked as d
join master.dbo.[_connection_limit_blocked] as b 
	on b.[program_name] = d.[program_name]
where b.action_type <> d.action_type
or b.connection_count <> d.connection_count


EXEC sp_WhoIsActive


INSERT master.dbo._connection_limit_config
SELECT [program_name] = 'sql-server-load-generator.py'
			 ,[limit] = 30
			 ,[reference] = 'testing-connection-limit';

UPDATE master.dbo._connection_limit_config
SET limit = 20
WHERE [program_name] = 'sql-server-load-generator.py'
*/
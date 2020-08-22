USE [master];
GO
IF OBJECT_ID('dbo.sqlg_parseRelogOutput') IS NULL EXECUTE sp_executesql N'CREATE PROCEDURE dbo.sqlg_parseRelogOutput AS RETURN';
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:      Raul Gonzalez @SQLDoubleG
-- Create date: 18/12/2017
-- Description: Formats the output generated by relog.exe and exists in the following tables.
--                  - CounterData
--                  - CounterDetails
--                  - DisplayToID
-- 
-- Parameters:
--              @dbname -> Name of the database where the Perfmon data exist
--              @CounterFilter -> To select only the counters that match the filter
--
-- Usage:       Call this stored proc and provide the name of the database where your perfmon logs have been loaded
--              It is recommended not to run in the same server we are trying to analyze due to the 
--                  amount of resources used by this query
--
--              EXECUTE master.[dbo].[sqlg_parseRelogOutput] N'Perfmon_logs', N'Processor';
--
-- Assumptions: You have loaded perfmon information using relog as explained in 
--                  https://www.sqldoubleg.com/2017/12/20/getting-perfmon-data-into-sql-server/
--
-- Change Log:  18/12/2017  RAG Created
--
-- Copyright:   (C) 2017 Raul Gonzalez (@SQLDoubleG https://www.sqldoubleg.com)
--
--              THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
--              ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
--              TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
--              PARTICULAR PURPOSE.
--
--              THE AUTHOR SHALL NOT BE LIABLE TO YOU OR ANY THIRD PARTY FOR ANY INDIRECT, 
--              SPECIAL, INCIDENTAL, PUNITIVE, COVER, OR CONSEQUENTIAL DAMAGES OF ANY KIND
--
--              YOU MAY ALTER THIS CODE FOR YOUR OWN *NON-COMMERCIAL* PURPOSES. YOU MAY
--              REPUBLISH ALTERED CODE AS LONG AS YOU INCLUDE THIS COPYRIGHT AND GIVE DUE CREDIT. 
--
-- =============================================
ALTER PROCEDURE [dbo].[sqlg_parseRelogOutput]
    @dbname sysname
    , @CounterFilter NVARCHAR(256) = NULL
AS
BEGIN
     
    DECLARE @column_list    NVARCHAR(MAX);
    DECLARE @pivot_list     NVARCHAR(MAX);
    DECLARE @SQL            NVARCHAR(MAX);
    DECLARE @RC             INT;
     
    IF DB_ID(@dbname) IS NULL BEGIN
        RAISERROR (N'The database provided does not exist', 16, 1, 1);
        RETURN -100;
    END;
 
    -- Get the different perfmon counters to be new columns for the output
    SET @SQL = N'USE ' + QUOTENAME(@dbname) + N'    
         
        IF OBJECT_ID(''dbo.CounterData'') IS NULL OR OBJECT_ID(''dbo.CounterDetails'') IS NULL BEGIN
            RAISERROR (N''The Relog generated tables are not present on this database, please ensure that [dbo].[CounterData], [dbo].[CounterDetails] and [dbo].[DisplayToID] exist'', 16, 1, 1)            
            RETURN
        END 
         
        SET @column_list = (SELECT DISTINCT N'', '' + QUOTENAME(CONCAT([ObjectName], CHAR(92), [CounterName], NULLIF(CONCAT(N'' ('', InstanceName, N'')''),N'' ()'' ))) AS [text()] 
                    FROM [dbo].[CounterDetails] 
                    WHERE [CounterName] LIKE CONCAT(N''%'', @CounterFilter + N''%'')
                    FOR XML PATH(''''))
 
        SET @pivot_list =   (STUFF(@column_list, 1, 2, ''''))';
 
    EXECUTE @RC = sys.sp_executesql
            @stmt = @SQL
            , @params = N'@column_list NVARCHAR(MAX) OUTPUT,@pivot_list NVARCHAR(MAX) OUTPUT, @CounterFilter NVARCHAR(256)'
            , @column_list = @column_list OUTPUT
            , @pivot_list = @pivot_list OUTPUT
            , @CounterFilter = @CounterFilter;
 
    IF @RC <> 0 BEGIN
        RETURN @RC;
    END;
 
    -- Now generate the the query with the right values to PIVOT and get the data out 
    SET @SQL = N'USE ' + QUOTENAME(@dbname) + N'    
     
    SELECT  [ComputerName]
            , [CounterDateTime]
            ' + @column_list + N'
        FROM (
            SELECT CONCAT(det.[ObjectName], CHAR(92), det.[CounterName], NULLIF(CONCAT('' ('', det.InstanceName, '')''),'' ()'' )) AS PermonCounter
                    ,did.[DisplayString] AS [ComputerName]
                    ,dat.[CounterDateTime] AS [CounterDateTime]
                    ,dat.[CounterValue]
                FROM [dbo].[CounterData] AS dat
                    LEFT JOIN [dbo].[CounterDetails] AS det
                        ON det.CounterID = dat.CounterID
                    LEFT JOIN [dbo].[DisplayToID] AS did
                        ON did.[GUID] = dat.[GUID]
                WHERE det.[CounterName] LIKE CONCAT(N''%'', @CounterFilter + N''%'')
            ) AS s
        PIVOT(
            SUM([CounterValue])
        FOR [PermonCounter] IN (' + @pivot_list + ' )) AS pvt
    ORDER BY [CounterDateTime] ASC';
 
    EXECUTE @RC = sys.sp_executesql
            @stmt = @SQL
            , @params = N'@CounterFilter NVARCHAR(256)'
            , @CounterFilter = @CounterFilter;
 
    IF @RC <> 0 BEGIN
        RETURN @RC;
    END;
 
END;
GO
 
EXECUTE master.[dbo].[sqlg_parseRelogOutput] N'DBA', N'Processor';
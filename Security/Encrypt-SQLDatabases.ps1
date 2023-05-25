[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [String]$SqlInstanceToEncrypt = 'SQLMonitor',

    [Parameter(Mandatory=$false)]
    [String[]]$DatabasesToEncrypt,

    [Parameter(Mandatory=$false)]
    [String]$DbaDatabase = 'DBA',

    [Parameter(Mandatory=$false)]
    [String]$InventoryServer = 'SQLMonitor',

    [Parameter(Mandatory=$false)]
    [String]$InventoryDatabase = 'DBA',

    [Parameter(Mandatory=$false)]
    [String]$CredentialManagerServer = 'SQLMonitor',

    [Parameter(Mandatory=$false)]
    [String]$CredentialManagerDatabase = 'DBA',

    [Parameter(Mandatory=$false)]
    [PSCredential]$SqlCredential = $personal,

    [Parameter(Mandatory=$false)]
    [PSCredential]$WindowsCredential,

    [Parameter(Mandatory=$false)]
    [String]$LocalBackupDirectory,

    [Parameter(Mandatory=$false)]
    [String]$RemoteBackupDirectory = 'D:\Work',

    [Parameter(Mandatory=$false)]
    [bool]$DryRun = $true
)

cls
$startTime = Get-Date
$ErrorActionPreference = "Stop"

$scriptOutfile = New-TemporaryFile
$horizontalLine = "`n/* " + ('*' * 50) + " */"

"-- ***** Implement Transparent Data Encryption (TDE) on server [$SqlInstanceToEncrypt]`n`n" | Out-File -FilePath $scriptOutfile

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'START:', "Working on server [$SqlInstanceToEncrypt]." | Write-Host -ForegroundColor Yellow

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "[Connect-DbaInstance] Create connection for InventoryServer '$InventoryServer'.."
$conInventoryServer = Connect-DbaInstance -SqlInstance $InventoryServer -Database $InventoryDatabase -ClientName "Encrypt-SQLDatabases.ps1" `
                                                    -SqlCredential $SqlCredential -TrustServerCertificate -ErrorAction Stop

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "[Connect-DbaInstance] Create connection for CredentialManagerServer '$CredentialManagerServer'.."
$conCredentialManagerServer = Connect-DbaInstance -SqlInstance $CredentialManagerServer -Database $CredentialManagerDatabase -ClientName "Encrypt-SQLDatabases.ps1" `
                                                    -SqlCredential $SqlCredential -TrustServerCertificate -ErrorAction Stop

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "[Connect-DbaInstance] Create connection for SqlInstanceToEncrypt '$SqlInstanceToEncrypt'.."
$conSqlInstanceToEncrypt = Connect-DbaInstance -SqlInstance $SqlInstanceToEncrypt -Database master -ClientName "Encrypt-SQLDatabases.ps1" `
                                                    -SqlCredential $SqlCredential -TrustServerCertificate -ErrorAction Stop

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Get basic details of '$SqlInstanceToEncrypt'.."
$sqlBasicDetails = @"
select	srv_name = '$SqlInstanceToEncrypt',
		at_server_name = @@SERVERNAME,
		server_name = convert(varchar,SERVERPROPERTY('ServerName')),
		domain = default_domain(),
		server_host_name = SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),
		total_database_count = (select count(*) from sys.databases d where d.state_desc = 'ONLINE' and is_read_only = 0 and d.database_id > 4),
		error_log_file = SERVERPROPERTY('ErrorLogFileName')
"@

$resultBasicDetails = Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlBasicDetails

$serverName = $resultBasicDetails.server_name
$atServerName = $resultBasicDetails.at_server_name
$domain = $resultBasicDetails.domain
$serverHostName = $resultBasicDetails.server_host_name
$totalDatabaseCount = $resultBasicDetails.total_database_count
$certificateName = $serverName+'__Certificate'
$certificateSubject = $serverName+' Certificate'


"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Configure Local Backup Directory.."
$backupDirectory = $LocalBackupDirectory
if([String]::IsNullOrEmpty($backupDirectory)) {
    $backupDirectory = Split-Path $resultBasicDetails.error_log_file
}


# If Errorlog path is not found, then use sp_readerrorlog to detect same
if([String]::IsNullOrEmpty($backupDirectory)) {
    $sqlGetErrorLog = "exec sp_readerrorlog 0,1,'Log\ERRORLOG','-e'"
    $resultGetErrorLog = @()
    $resultGetErrorLog += Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlGetErrorLog
    if($resultGetErrorLog[0].Text -match "\s+-e\s(?'log_directory'.+)\\ERRORLOG") {
        $backupDirectory = $Matches['log_directory']
    }
}

if(-not $backupDirectory.EndsWith('\')) {
    $backupDirectory = $backupDirectory + '\'
}


# Get Encryption Password
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Fetch Encryption Password from Credential Manager.."
$sqlFetchPassword = @"
-- Get Encryption Password for [$SqlInstanceToEncrypt]
select	top 1 server_ip, server_name, [user_name], 
		[password] = cast(DecryptByPassPhrase(cast(salt as varchar),password_hash ,1, server_ip) as varchar)
from dbo.credential_manager cm
where cm.server_ip = '$SqlInstanceToEncrypt'
and user_name = 'master key'
"@

"`n`n-- Execute below on [$CredentialManagerServer].[$CredentialManagerDatabase]`n" + $sqlFetchPassword + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
$resultFetchPassword = @()
$resultFetchPassword += Invoke-DbaQuery -SqlInstance $conCredentialManagerServer -Database $CredentialManagerDatabase -Query $sqlFetchPassword

# If password does not exist, then create a new one
if($resultFetchPassword.Count -eq 0) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Generate Encryption Password as not found in Credential Manager."
    $encryptionPassword = -Join("ABCDabcd&@#$%1234".tochararray() | Get-Random -Count 10 | % {[char]$_})
}
else {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Encryption Password found in Credential Manager."
}


# Save Encryption Password
if($resultFetchPassword.Count -eq 0) 
{
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Save Encryption Password in Credential Manager.."
    $params = @{
                    server_ip = $SqlInstanceToEncrypt
                    server_name = $serverName
                    user_name = 'master key'
                    password_string = $encryptionPassword
                    remarks = 'Database Master Key'
            }
    Invoke-DbaQuery -SqlInstance $conCredentialManagerServer -Database $CredentialManagerDatabase `
            -Query usp_add_credential -SqlParameter $params -CommandType StoredProcedure
}

$sqlAddEncryptionPasswordOnCredentialManager = @"
-- Save Encryption Key on Credential Manager
exec dbo.usp_add_credential
			@server_ip = '$SqlInstanceToEncrypt',
			@server_name = '$serverName',
			@user_name = 'master key',
			@password_string = '$encryptionPassword',
			@remarks = 'Database Master Key';
"@
"`n`n-- Execute below on [$CredentialManagerServer].[$CredentialManagerDatabase]`n" + $sqlAddEncryptionPasswordOnCredentialManager + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append


# Initialize Derived Variables
$certificatePath = $backupDirectory + $certificateName + '.crt'
$masterKeyPath = $backupDirectory + $serverName + '__master_key.key'
$privateKeyPath = $backupDirectory + $serverName + '__private_key.pvk'


# Create Master Key
$sqlCreateMasterKey = @"
-- Create master key
if not exists (select * from sys.symmetric_keys where name LIKE '%DatabaseMasterKey%')
begin    
	exec ('use master; create master key encryption by password = ''$encryptionPassword'';');
    print 'DMK created';
end
else
    print 'DMK exists';
"@

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Create Master Key.."
$sqlCreateMasterKey + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
if($DryRun) {
    $sqlCreateMasterKey | Write-Host -ForegroundColor Magenta
}
else {
    Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlCreateMasterKey `
                    -MessagesToOutput | Write-Host -ForegroundColor Cyan
}



# Create Certificate
$sqlCreateCertificate = @"
-- Create certificate
declare @sql nvarchar(max);
declare @thumbprint varbinary(64);

select @thumbprint = c.thumbprint from sys.certificates c 
	where issuer_name = '$certificateSubject' and name = '$certificateName';

if @thumbprint is null
begin
	set @sql = 'use master; create certificate [$certificateName] with subject = ''$certificateSubject'';';
	exec (@sql);
    print 'certificate created';
end
else
	print 'Certificate already exists';
"@

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Create Certificate.."
$sqlCreateCertificate + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
if($DryRun) {
    $sqlCreateCertificate | Write-Host -ForegroundColor Magenta
}
else {
    Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlCreateCertificate `
                    -MessagesToOutput | Write-Host -ForegroundColor Cyan
}


# List databases to Encrypt
$sqlGetAllUserDatabases = @"
select [database_name] = d.name 
from sys.databases d 
where 1=1
    and d.state_desc = 'ONLINE' 
    and is_read_only = 0 
    and d.database_id > 4
	and d.is_encrypted = 0
	and d.source_database_id is null
"@

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Get list of dbs to Encrypt.."
$resultGetAllUserDatabases = @()
$resultGetAllUserDatabases += Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master `
                                -Query $sqlGetAllUserDatabases | Select-Object -ExpandProperty database_name


# Loop through each database, and generate encryption key
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Loop through each database & generate Encryption Key.."
foreach($database in $resultGetAllUserDatabases)
{
    $sqlGenerateEncryptionKey = @"
declare @sql nvarchar(max);
declare @thumbprint varbinary(64);

use [master];
-- Get certificate thumbprint
select @thumbprint = c.thumbprint from sys.certificates c 
	where issuer_name = '$certificateSubject' and name = '$certificateName';

use [$database];
-- Create encryption key
if not exists (select * from sys.dm_database_encryption_keys dek where dek.database_id = DB_ID()
					and dek.encryptor_type = 'CERTIFICATE' and dek.key_length = 128 
					and dek.encryptor_thumbprint = @thumbprint )
begin
	set @sql = 'use '+quotename(DB_NAME())+'; '
                +char(9)+'create database encryption key with algorithm = aes_128 '
	            +char(9)+char(9)+'encryption by server certificate [$certificateName];';
	exec (@sql);
    print 'Encryption Key created on [$database].'
end
else
	print 'Database Encryption key exists';
"@
    
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Working on [$database].."
    $sqlGenerateEncryptionKey + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
    if($DryRun) {
        $sqlGenerateEncryptionKey | Write-Host -ForegroundColor Magenta
    }
    else {
        Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlGenerateEncryptionKey `
                    -MessagesToOutput | Write-Host -ForegroundColor Cyan
    }
}


# Backup Certificate
$sqlBackupCertificate = @"
-- Backup Certificate & Master Key
use master;

declare @sql nvarchar(max);

exec xp_create_subdir '$backupDirectory';

/* **** If Cleanup of Files is required ****
DECLARE @cmd NVARCHAR(MAX);

SET @cmd = 'xp_cmdshell ''del "$masterKeyPath"''';
EXEC (@cmd); -- remove master key file

SET @cmd = 'xp_cmdshell ''del "$certificatePath"'''; 
EXEC (@cmd); -- remove certificate file

SET @cmd = 'xp_cmdshell ''del "$privateKeyPath"'''; 
EXEC (@cmd); -- remove private key file
*/

-- Backup master key
set @sql = 'use master; backup master key to file = ''$masterKeyPath'' encryption by password = ''$encryptionPassword''';
exec (@sql);

-- Backup certificate
set @sql = 'use master; backup certificate [$certificateName]
	to file = ''$certificatePath''
	with private key (
		file = ''$privateKeyPath'',
		encryption by password = ''$encryptionPassword''
	)';
exec (@sql);

/* IMPORTANT: COPY these files to some secure location Immediately before proceeding */

"@

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Backup certificate & Master Key to [$backupDirectory] on $SqlInstanceToEncrypt.."
$sqlBackupCertificate + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
if($DryRun) {
    $sqlBackupCertificate | Write-Host -ForegroundColor Magenta
}
else {
    Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlBackupCertificate `
                    -MessagesToOutput | Write-Host -ForegroundColor Cyan
}


# Loop through each database, and Encrypt it
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Loop through each database to Encrypt.."
foreach($database in $resultGetAllUserDatabases)
{
    $sqlEncryptDatabase = @"
-- Enable Encryption
use [master]; alter database [$database] set encryption on;
"@
    
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Encrypting [$database].."
    $sqlEncryptDatabase + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
    if($DryRun) {
        $sqlEncryptDatabase | Write-Host -ForegroundColor Magenta
    }
    else {
        Invoke-DbaQuery -SqlInstance $conSqlInstanceToEncrypt -Database master -Query $sqlEncryptDatabase `
                    -MessagesToOutput | Write-Host -ForegroundColor Cyan
    }
}


# Save Encryption Details on [CredentialManagerServer]
$sqlSaveEncryptionDetails = @"
-- Save Encryption Details of [$SqlInstanceToEncrypt]
-- Execute below on [$CredentialManagerServer].[$CredentialManagerDatabase]
if not exists (select * from dbo.tde_implementation_details where srv_name = '$SqlInstanceToEncrypt' and server_name = '$serverName' and server_host_name = '$serverHostName')
begin
	insert dbo.tde_implementation_details
    ( [srv_name], [at_server_name], [server_name], [domain], [server_host_name], [encrypted_databases], [total_database_count], [encryption_start_time], [encryption_end_time], [local_backup_directory], [remote_backup_directory], [certificate_name], [certificate_subject], [encryption_password], [certificate_file_path], [master_key_path], [private_key_path], [files_copied_to_remote] )
    select	[srv_name] ='$SqlInstanceToEncrypt', 
		    [at_server_name] = '$atServerName', 
		    [server_name] = '$serverName', 
		    [domain] = '$domain', 
		    [server_host_name] = '$serverHostName', 
		    [encrypted_databases] = $($resultGetAllUserDatabases.Count), 
		    [total_database_count] = $($resultGetAllUserDatabases.Count), 
		    [encryption_start_time] = SYSDATETIME(), 
		    [encryption_end_time] = null, 
		    [local_backup_directory] = '$backupDirectory', 
		    [remote_backup_directory] = '$RemoteBackupDirectory', 
		    [certificate_name] = '$certificateName', 
		    [certificate_subject] = '$certificateSubject', 
		    [encryption_password] = null, 
		    [certificate_file_path] = '$certificatePath', 
		    [master_key_path] = '$masterKeyPath', 
		    [private_key_path] = '$privateKeyPath', 
		    [files_copied_to_remote] = 0;
    
    print 'TDE Entry added for [$SqlInstanceToEncrypt].'
end
else
    print 'TDE Entry already exists for [$SqlInstanceToEncrypt].'
"@

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Save encryption details of [$SqlInstanceToEncrypt] on [$CredentialManagerServer].[$CredentialManagerDatabase].[dbo].[tde_implementation_details]."
$horizontalLine + "`n" + $sqlSaveEncryptionDetails + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
$sqlSaveEncryptionDetails | Write-Host -ForegroundColor Magenta

Invoke-DbaQuery -SqlInstance $conCredentialManagerServer -Database $CredentialManagerDatabase -Query $sqlSaveEncryptionDetails `
                -MessagesToOutput | Write-Host -ForegroundColor Cyan



# Scripts to Check Encryption Status
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Kindly use below query to check Encryption Status.."
$sqlCheckEncryptionStatus = @"
USE [master];
-- Check Encryption Status
SELECT DB_NAME(database_id) as dbName, encryption_state_desc, percent_complete,
		encryptor_thumbprint,
		[encryption_key_create_date] = regenerate_date,
		encryption_scan_state_desc,
		*
FROM sys.dm_database_encryption_keys 
WHERE database_id > 4
--and DB_NAME(database_id) in ('')
"@
$horizontalLine + "`n" + $sqlCheckEncryptionStatus + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
$horizontalLine + "`n" + $sqlCheckEncryptionStatus | Write-Host -ForegroundColor Magenta


# Scripts to Restore Certificate/Private Key
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Kindly use below query to Restore Certificate/Private Key.."
$sqlRestoreCertificate = @"
USE [master];
-- For Restore Scenario (AG/Mirroring/LogShipping/Backup-Restore)
create master key encryption by /* Step 1: Unique to Destination Server */
	password = '<<Some Very Strong Password Here. Unique to each server>>';

-- For Restore Scenario (AG/Mirroring/LogShipping/Backup-Restore)
create certificate [$certificateName] /* Step 2: Details similar to Source Server */
	from file = '$certificatePath'
	with private key (
		file = '$privateKeyPath',
		decryption by password = '$encryptionPassword'
	);
"@
$horizontalLine + "`n" + $sqlRestoreCertificate + "`nGO`n" | Out-File -FilePath $scriptOutfile -Append
$horizontalLine + "`n" + $sqlRestoreCertificate | Write-Host -ForegroundColor Magenta


"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Opening scriptout file '$scriptOutfile'.."
notepad $scriptOutfile

<#
Import-Module dbatools

# $DomainCredential = Get-Credential -UserName 'Lab\SQLServices' -Message 'AD Account'
# $saAdmin = Get-Credential -UserName 'sa' -Message 'sa'
# $localAdmin = Get-Credential -UserName 'Administrator' -Message 'Local Admin'
# $personal = Get-Credential -UserName 'E84947' -Message 'E84947'

D:\GitHub-Personal\SQLMonitor\Work\Encrypt-SQLDatabases.ps1 -SqlInstanceToEncrypt '172.31.39.70' -SqlCredential $personal
#>
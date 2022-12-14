[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$NoOfIterations = 50,
    [Parameter(Mandatory=$false)]
    [int]$NoOfThreads = 6,
    [Parameter(Mandatory=$false)]
    [string]$SqlInstance = 'localhost',
    [Parameter(Mandatory=$false)]
    [string]$Database = 'StackOverflow',
    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenQueriesMS = 1000,
    [Parameter(Mandatory=$false)]
    [pscredential]$SqlCredential
)

$startTime = Get-Date
#Import-Module dbatools, PoshRSJob;

$ErrorActionPreference = "Stop"

$loops = 1..$($NoOfThreads*$NoOfIterations)
$scriptBlock = {
    Param ($SqlInstance, $Database, $SqlCredential)
    
    #Import-Module dbatools;
    $id1 = Get-Random -Maximum 10000000
    $id2 = Get-Random -Maximum 10000000
    $id3 = Get-Random -Maximum 10000000

    # Set application/program name
    $appName = switch ($id1 % 5) {
        0 {"SQLQueryStress"}
        1 {"dbatools"}
        2 {"VS Code"}
        3 {"PowerShell"}
        4 {"Azure Data Studio"}
    }

    # Randonly call b/w 2 logins
    if ( $appName -eq 'SQLQueryStress' ) {
        $con = Connect-DbaInstance -SqlInstance $SqlInstance -Database $Database -SqlCredential $SqlCredential -ClientName $appName
    }
    else {
        $con = Connect-DbaInstance -SqlInstance $SqlInstance -Database $Database -ClientName $appName
    }

    # Call various procedures
    if (($id1 % 12) -eq 0) { # 1/12 chance
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q3160 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    <#
    elseif (($id1 % 12) -eq 1) { # 1/10 chance
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Bounties_and_Questions_by_Month -CommandType StoredProcedure
    } #>
    elseif (($id1 % 11) -eq 0) { # 1/11 chance
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q36660 $id1;"
    }
    elseif (($id1 % 10) -eq 0) { # 1/10 chance
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q466 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    <#
    elseif (($id1 % 9) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q6627 $id1;"
    }
    #>
    elseif (($id1 % 8) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q6772 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    elseif (($id1 % 7) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q6856 $id1;"
    }
    elseif (($id1 % 6) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q7521 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    elseif (($id1 % 5) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q8116 $id1;"
    }
    elseif (($id1 % 4) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q947 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    elseif (($id1 % 3) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q949 $id1;"
    }
    elseif (($id1 % 2) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_Q952 -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    <#
    elseif (($id1 % 3) -eq 1) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_get_user_comment_score_distribution -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    }
    elseif (($id1 % 3) -eq 2) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_get_user_score -SqlParameter @{ UserId = $id1 } -CommandType StoredProcedure
    } #>
    else {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_Q975 $id1;"
    }
}
$jobs = $loops | Start-RSJob -Name {"RandomQ__$_"} -ScriptBlock $scriptBlock -Throttle $NoOfThreads -ModulesToImport dbatools -ArgumentList $SqlInstance, $Database, $SqlCredential

# Get all the jobs
$jobs | Wait-RSJob -ShowProgress

$jobs | Remove-RSJob -Force;

$endTime = Get-Date

$elapsedTime = New-TimeSpan -Start $startTime -End $endTime

"Total time taken = $("{0:N0}" -f $elapsedTime.TotalHours) hours $($elapsedTime.Minutes) minutes $($elapsedTime.Seconds) seconds" | Write-Host -ForegroundColor Yellow


<#
cd $env:USERPROFILE\documents\Lab-Load-Generator\
#$SqlCredential = Get-Credential -UserName 'SQLQueryStress' -Message 'SQLQueryStress'

$params = @{
    SqlInstance = 'SqlPractice'
    Database = 'StackOverflow'
    NoOfIterations = 500
    NoOfThreads = 6
    DelayBetweenQueriesMS = 1000
    SqlCredential = $SqlCredential
}

cls
Import-Module dbatools, PoshRSJob;
.\Invoke-RandomQ.ps1 @params
#>
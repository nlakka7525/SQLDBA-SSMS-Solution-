[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$NoOfIterations = 100,
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
Import-Module dbatools, PoshRSJob;

$ErrorActionPreference = "Stop"

if ([String]::IsNullOrEmpty($SqlCredential)) {
    "Kindly provide `$SqlCredential " | Write-Error
}

$loops = 1..$($NoOfThreads*$NoOfIterations)
$scriptBlock = {
    Param ($SqlInstance, $Database, $SqlCredential, $DelayBetweenQueriesMS)
    
    # Import-Module dbatools
    $id1 = Get-Random
    $id2 = Get-Random
    $id3 = Get-Random

    # Set application/program name
    $appName = switch ($Id1 % 5) {
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

    if (($id1 % 30) -eq 24) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_Q1718 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 23) {
        $r = Invoke-DbaQuery -SqlInstance $con -CommandType StoredProcedure -Query usp_Q2777
    }
    elseif (($id1 % 30) -eq 22) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_Q181756 @Score = $id1, @Gold = $id2, @Silver = $id3;"
    }
    elseif (($id1 % 30) -eq 21) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q69607 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 20) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q8553 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 19) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q10098 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 18) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q17321 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 17) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q25355 -CommandType StoredProcedure -SqlParameter @{ MyId = $id1; TheirId = $id2 }
    }
    elseif (($id1 % 30) -eq 16) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q74873 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 15) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_Q9900 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 14) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q49864 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 13) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q283566 -CommandType StoredProcedure
    }
    elseif (($id1 % 30) -eq 12) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q66093 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 11) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q66093 -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 10) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_SearchUsers @DisplayNameLike = 'Brent', @LocationLike = NULL, @WebsiteUrlLike = 'Google', @SortOrder = 'Age';"
    }
    elseif (($id1 % 30) -eq 9) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = 'Chicago', @WebsiteUrlLike = NULL, @SortOrder = 'Location';"
    }
    elseif (($id1 % 30) -eq 8) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = NULL, @WebsiteUrlLike = 'BrentOzar.com', @SortOrder = 'Reputation';"
    }
    elseif (($id1 % 30) -eq 7) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_SearchUsers -CommandType StoredProcedure -SqlParameter `
                    @{ DisplayNameLike = 'Brent'; LocationLike = 'Chicago'; WebsiteUrlLike = 'BrentOzar.com'; SortOrder = 'DownVotes'; } 
    }
    elseif (($id1 % 30) -eq 6) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_FindInterestingPostsForUser -CommandType StoredProcedure -SqlParameter `
                    @{ UserId = $id1; SinceDate = '2017/06/10'; }
    }
    elseif (($id1 % 30) -eq 5) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CheckForVoterFraud -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 4) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_AcceptedAnswersByUser -CommandType StoredProcedure -SqlParameter @{ UserId = $id1 }
    }
    elseif (($id1 % 30) -eq 3) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_AcceptedAnswersByUser -CommandType StoredProcedure -SqlParameter @{ UserId = $id3 }
    }
    elseif (($id1 % 30) -eq 2) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_BadgeAward -CommandType StoredProcedure -SqlParameter @{ Name = 'Loud Talker'; UserId = 26837 }
    }
    elseif (($id1 % 30) -eq 1) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q43336 -CommandType StoredProcedure
    }
    else {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q40304 -CommandType StoredProcedure
    }
    Start-Sleep -Milliseconds $DelayBetweenQueriesMS
}
$jobs = $loops | Start-RSJob -Name {"IndexLab6__$_"} -ScriptBlock $scriptBlock -Throttle $NoOfThreads -ModulesToImport dbatools `
            -ArgumentList $SqlInstance, $Database, $SqlCredential, $DelayBetweenQueriesMS

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
    NoOfIterations = 20
    NoOfThreads = 6
    DelayBetweenQueriesMS = 1000
    SqlCredential = $SqlCredential
}

cls
Import-Module dbatools, PoshRSJob;
.\Invoke-IndexLab6.ps1 @params
#>
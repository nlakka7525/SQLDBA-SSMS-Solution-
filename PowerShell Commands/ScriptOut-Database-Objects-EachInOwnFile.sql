<#  Method 01 -> Each object with its own sql file
	Script to Scriptout Databases & Objects
    Each database goes in single folder.
    Each object goes in its own sql file.

	https://www.mssqltips.com/sqlservertip/4606/generate-tsql-scripts-for-all-sql-server-databases-and-all-objects-using-powershell/
#>
cls
$startTime = Get-Date
$timeString = ($startTime.ToString("yyyyMMdd_HHmm"))
$ServerName = "localhost" #If you have a named instance, you should put the name. 
$path = "C:\Users\Ajay\Documents\Scriptout-Testing\"+"$timeString"

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Creating SMO for SqlInstance '$ServerName'.."
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
$IncludeTypes = @("Tables","StoredProcedures","Views","UserDefinedFunctions", "Triggers") #object you want do backup. 
$ExcludeSchemas = @("sys","Information_Schema")
$so = new-object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions')

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Get all databases for SqlInstance '$ServerName'.."
$dbs = $serverInstance.Databases #you can change this variable for a query for filter yours databases.
$dbCounts = $dbs.Count

$counter = 1
foreach ($db in $dbs)
{
    $dbname = "$db".replace("[","").replace("]","")
    $dbpath = "$path"+ "\"+"$dbname" + "\"
    if ( !(Test-Path $dbpath) ) {
        $null = new-item -type directory -name "$dbname" -path "$path"
    }

    "`n$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "$counter/$dbCounts) Scriptout database [$dbname] on path '$dbpath'.." | Write-Host -ForegroundColor Yellow

    $OutFile = "$dbpath" + "$dbname" + ".sql"
    try {
        $db.Script($so)+"GO" | out-File $OutFile
 
        foreach ($Type in $IncludeTypes)
        {
            "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Working on $Type.."
            $objpath = "$dbpath" + "$Type" + "\"
            if ( !(Test-Path $objpath) ) {
                $null = new-item -type directory -name "$Type"-path "$dbpath"
            }
            foreach ($objs in $db.$Type) {
                If ($ExcludeSchemas -notcontains $objs.Schema ) {
                    $ObjName = "$objs".replace("[","").replace("]","")                  
                    $OutFile = "$objpath" + "$ObjName" + ".sql"
                    try {
                        $objs.Script($so)+"GO" | out-File $OutFile
                    }
                    catch {
                        $errMessage = $_

                        "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "Below error occurred while trying to script $Type '$ObjName'." | Write-Host -ForegroundColor Red
                        $($errMessage.Exception.Message -Split [Environment]::NewLine) | % {"`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "$_"} | Write-Host -ForegroundColor Red

                        #Write-Error "Stop here. Fix above issue."
                    }
                }
            }
        }
    }
    catch {
        $errMessage = $_

        "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "Below error occurred while scripting database '$dbname'." | Write-Host -ForegroundColor Red
        "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "So skipping to next database." | Write-Host -ForegroundColor Red
        $($errMessage.Exception.Message -Split [Environment]::NewLine) | % {"`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "$_"} | Write-Host -ForegroundColor Red
    }
    $counter += 1
}

$endTime = Get-Date
$timeElapsed = New-TimeSpan -Start $startTime -End $endTime
"`n$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Total time in minutes => $($timeElapsed.TotalMinutes)" | Write-Host -ForegroundColor Green

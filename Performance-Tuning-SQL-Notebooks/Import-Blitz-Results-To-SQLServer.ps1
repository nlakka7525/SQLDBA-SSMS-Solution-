[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [String]$SQLNotebookPath = 'D:\SQLPractice\',
    [Parameter(Mandatory=$true)]
    [String]$SqlInstance
)

# Install PowerShellNotebook
#Install-Module -Scope AllUsers -Name PowerShellNotebook
Import-Module PowerShellNotebook

# ======================== BEGIN ==========================
# Activity 01 -> Rename sample files to new date
# ---------------------------------------------------------
$FileNamePattern_Existing = 'Wed-Aug31'
$FileNamePattern_New = 'Wed-Sep07'

$files2Rename = @()
$files2Rename += Get-ChildItem -Path $SQLNotebookPath | ? {$_.Name -match "$FileNamePattern_Existing" }
foreach($file in $files2Rename) {
    $newName = $file.Name -replace $FileNamePattern_Existing, $FileNamePattern_New
    "Renaming '$($file.Name)' to '$newName'" | Write-Host -ForegroundColor Cyan
    $file | Rename-Item -NewName $newName
}
# ======================== END ============================


# ======================== BEGIN ==========================
# Activity 02 -> Execute all SQLNotebooks
# ---------------------------------------------------------
Invoke-SqlNotebook -ServerInstance SQLDEMO2019 -Database master -InputFile '.\BPCheck.ipynb' -OutputFile 'BPCheck_output.ipynb';


# ======================== END ============================


# ======================== BEGIN ==========================
# Activity 03 -> Import BlitzIndex to SQL Tables
# ---------------------------------------------------------
#$personal = Get-Credential -UserName 'sa' -Message 'Personal'
$Server = 'SQLPractice'
$IndexSummaryFile = 'D:\SQLPractice\sp_BlitzIndex-Summary-Fri-Aug26.xlsx'
$IndexDetailedFile = 'D:\SQLPractice\sp_BlitzIndex-Detailed-Fri-Aug26.xlsx'

Import-Excel $IndexSummaryFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA_Admin' -Table 'BlitzIndex_Summary_Aug26' -SqlCredential $personal -AutoCreateTable
Import-Excel $IndexDetailedFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA_Admin' -Table 'BlitzIndex_Detailed_Aug26' -SqlCredential $personal -AutoCreateTable


EXEC sp_rename 'dbo.ErrorLog.ErrorTime', 'ErrorDateTime', 'COLUMN';
# ======================== END ============================
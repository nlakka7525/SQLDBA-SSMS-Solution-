#$personal = Get-Credential -UserName 'sa' -Message 'Personal'
$Server = 'SqlPractice'
$IndexSummaryFile = '\\SomePath\sp_BlitzIndex-Summary-Wed-Aug31.xlsx'
$IndexDetailedFile = '\\SomePath\sp_BlitzIndex-Detailed-Wed-Aug31.xlsx'

Import-Excel $IndexSummaryFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA_Admin' -Table 'BlitzIndex_Summary_Aug31' -SqlCredential $personal -AutoCreateTable
Import-Excel $IndexDetailedFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA_Admin' -Table 'BlitzIndex_Detailed_Aug31' -SqlCredential $personal -AutoCreateTable


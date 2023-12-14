Register-PSFTeppScriptblock -Name Maester.Checks.Name -ScriptBlock {
	(Get-MtCheck).Name | Sort-Object
} -Global

Register-PSFTeppScriptblock -Name Maester.Checks.Tags -ScriptBlock {
	(Get-MtCheck).Tags | Sort-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name Maester.Checks.Category -ScriptBlock {
	(Get-MtCategory).Name | Sort-Object
} -Global
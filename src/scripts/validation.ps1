Set-PSFScriptblock -Name Maester.Validate.Name -Scriptblock {
	$_ -match '^[\d\w_\-]+$'
}
function Resolve-MtCheckParameter {
	<#
	.SYNOPSIS
		Resolves the parameters to use in checks.

	.DESCRIPTION
		Resolves the parameters to use in checks.
		While mostly used internally, this allows you to troubleshoot checks not receiving the parameters they should have received.

	.PARAMETER Name
		The name of the check to resolve the parameters for.
		Must be an exact match, not wildcard

	.EXAMPLE
		PS C:\> Reolve-MtCheckParameter -Name GlobalAdminCount

		Resolves the parameters that would be passed to the "GlobalAdminCount" check.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('Maester.Checks.Name')]
		[string]
		$Name
	)
	process {
		$check = Get-MtCheck -Name $Name | Where-Object Name -EQ $Name
		if (-not $check) { throw "Check not found: $Name" }

		$param = $check.Config.Clone()
		$config = Select-PSFConfig -FullName "Maester.Checks.$Name.*" -Depth 2

		foreach ($key in $param.Keys | Write-Output) {
			if ($null -ne $config.$key) { $param.$key = $config.$key }
		}
		$param
	}
}
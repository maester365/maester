function Invoke-MtCheck {
	<#
	.SYNOPSIS
		Executes all registered checks.

	.DESCRIPTION
		Executes all registered checks.
		Be sure to first connect to your tenant before executing this!

	.PARAMETER Tags
		Only executes the checks with these Tags.
		By default, all checks are being executed.

	.EXAMPLE
		PS C:\> Invoke-MtCheck

		Executes all registered checks.
	#>
	[CmdletBinding()]
	param (
		[PsfArgumentCompleter('Maester.Checks.Tags')]
		[string[]]
		$Tags
	)
	process {
		Import-Module Pester

		$config = [PesterConfiguration]::Default
		$config.Run.Path = "$script:ModuleRoot\content\checks.Tests.ps1"
		# If we want to manually process the test results
		# $config.Run.PassThru = $true

		# Verbosity: 'None', 'Normal', 'Detailed', 'Diagnostic'
		$config.Output.Verbosity = 'Detailed'

		if ($Tags) {
			$config.Filter.Tag = $Tags
		}
		Invoke-Pester -Configuration $config
	}
}
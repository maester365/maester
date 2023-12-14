function Get-MtCheck {
	<#
	.SYNOPSIS
		List all registered maester checks.

	.DESCRIPTION
		List all registered maester checks.

	.PARAMETER Name
		Filter for a specific name or name-pattern.
		Defaults to: *

	.PARAMETER Tags
		Only return checks with at least one matching tag.

	.EXAMPLE
		PS C:\> Get-MtCheck

		List all registered maester checks.
	#>
	[CmdletBinding()]
	param (
		[PsfArgumentCompleter('Maester.Checks.Name')]
		[string]
		$Name = '*',

		[PsfArgumentCompleter('Maester.Checks.Tags')]
		[string[]]
		$Tags = @()
	)
	process {
		($script:checks.Values) | Where-Object {
			$_.Name -like $Name -and
			(
				-not $Tags -or
				($_.Tags | Where-Object { $_ -in $Tags })
			)
		}
	}
}
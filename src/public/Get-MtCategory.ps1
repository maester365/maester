function Get-MtCategory {
	<#
	.SYNOPSIS
		Lists all registered categories.

	.DESCRIPTION
		Lists all registered categories.

	.PARAMETER Name
		Filter for a specific name.
		Defaults to: *

	.PARAMETER AsHashtable
		Return results as a hashtable instead.

	.EXAMPLE
		PS C.\> Get-MtCategory

		Lists all registered categories.
	#>
	[CmdletBinding()]
	param (
		[string]
		$Name = '*',

		[switch]
		$AsHashtable
	)
	process {
		if (-not $AsHashtable) {
			($script:categories.Values) | Where-Object Name -Like $Name
			return
		}

		$result = @{ }
		foreach ($category in $script:categories.Values) {
			if ($category.Name -notlike $Name) { continue }
			$result[$category.Name] = $category.Description
		}
		$result
	}
}
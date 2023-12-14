function Register-MtCategory {
	<#
	.SYNOPSIS
		Registers a new category of checks.

	.DESCRIPTION
		Registers a new category of checks.
		Categories are the top level grouping of checks in the result (the describe section in the test).

		Defining categories is not a requirement for using them, but it enables providing a better explanation, of what is being tested for.

	.PARAMETER Name
		Name of the category.
		This is referenced by all checks that should be part of this category.

	.PARAMETER Description
		The text to show in the tests

	.EXAMPLE
		PS C.\> Register-MtCategory -Name Privileges -Description 'Checking the assignments of administrative privileges'

		Registers the "Privileges" category.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfValidateScript('Maester.Validate.Name', ErrorMessage = 'name can only contain letters, numbers or dashes')]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$Description
	)
	process {
		$script:categories[$name] = [PSCustomObject]@{
			PSTypeName  = 'Maester.Checks.Category'
			Name        = $Name
			Description = $Description
		}
	}
}
function Register-MtCheck {
	<#
	.SYNOPSIS
		Registers a check that will be executed when Maester is run.

	.DESCRIPTION
		Registers a check that will be executed when Maester is run.
		The code provided must execute the inner part of a pester test (what happens in a single "It" statement)

	.PARAMETER Name
		The name of the check - must be unique, will overwrite a previous check of the same name.

	.PARAMETER Message
		The message included in the test.
		This is the text describing what is being tested and should explain to the user, what was being tested.

	.PARAMETER Category
		The category the check is part of.
		This maps to the "Describe" section of the test.

	.PARAMETER Code
		The code performing the actual testing logic.
		It receives a single argument - a hashtable of its settings.
		Its logic must  include one ore more "Should" statements..
		Example:

		param ($Param)
		(Get-MtGlobalAdmin -Permanent).Count | Should -BeLessOrEqual $Param.MaxCount

	.PARAMETER Tags
		Any tags to include in the check.
		Tags allow executing only a specific subset of checks in a given run.

	.PARAMETER Config
		The settings a check supports and its default values.

	.EXAMPLE
		PS C:\> Register-MtCheck -Name GlobalAdminCount -Message 'Should have only few permanent global admins' -Tags Graph, Privilege -Config @{ MaxCount = 3 } -Code {
			param ($Param)
			(Get-MtGlobalAdmin -Permanent).Count | Should -BeLessOrEqual $Param.MaxCount
		}

		Registers a check that verifies only a limited number of permanent global admins exist.
		The command retrieving the global admin accounts (Get-MtGlobalAdmin) would need to be implemented separately, or provided as part of the scriptblock.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfValidateScript('Maester.Validate.Name', ErrorMessage = 'name can only contain letters, numbers or dashes')]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$Message,

		[Parameter(Mandatory = $true)]
		[PsfValidateScript('Maester.Validate.Name', ErrorMessage = 'category can only contain letters, numbers or dashes')]
		[PsfArgumentCompleter('Maester.Checks.Category')]
		[string]
		$Category,

		[Parameter(Mandatory = $true)]
		[ScriptBlock]
		$Code,

		[PsfArgumentCompleter('Maester.Checks.Tags')]
		[string[]]
		$Tags = @(),

		[hashtable]
		$Config = @{}
	)
	process {
		$script:checks[$Name] = [PSCustomObject]@{
			PSTypeName = 'Maester.Checks.Check'
			Name       = $Name
			Message    = $Message
			Category   = $Category
			Tags       = $Tags
			Code       = $Code
			Config     = $Config
		}
	}
}
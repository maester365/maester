<#
    .NOTES
        The original test this is based upon was written by June Blender.
		After several rounds of modifications it stands now as it is, but the honor remains hers.

		Thank you June, for all you have done!

    .DESCRIPTION
		This test evaluates the help for all commands in a module.

	.PARAMETER SkipTest
		Disables this test.

	.PARAMETER CommandPath
		List of paths under which the script files are stored.
		This test assumes that all functions have their own file that is named after themselves.
		These paths are used to search for commands that should exist and be tested.
		Will search recursively and accepts wildcards, make sure only functions are found

	.PARAMETER ModuleName
		Name of the module to be tested.
		The module must already be imported

	.PARAMETER ExceptionsFile
		File in which exceptions and adjustments are configured.
		In it there should be two arrays and a hashtable defined:
			$global:FunctionHelpTestExceptions
			$global:HelpTestEnumeratedArrays
			$global:HelpTestSkipParameterType
		These can be used to tweak the tests slightly in cases of need.
		See the example file for explanations on each of these usage and effect.
#>
[CmdletBinding()]
Param (
	[switch]
	$SkipTest,

	[string[]]
	$CommandPath = @("$PSScriptRoot\..\..\public", "$PSScriptRoot\..\..\internal"),

	[string]
	$ModuleName = "PSFramework",

	[string]
	$ExceptionsFile = "$PSScriptRoot\..\general\Help.Exceptions.ps1"
)
if ($SkipTest) { return }
. $ExceptionsFile

$includedNames = (Get-ChildItem $CommandPath -Recurse -File | Where-Object Name -like "*.ps1").BaseName
$commandTypes = @('Cmdlet', 'Function')
if ($PSVersionTable.PSEdition -eq 'Desktop' ) { $commandTypes += 'Workflow' }
$commands = Get-Command -Module (Get-Module $ModuleName) -CommandType $commandTypes | Where-Object Name -In $includedNames

## When testing help, remember that help is cached at the beginning of each session.
## To test, restart session.


foreach ($command in $commands) {
    $commandName = $command.Name

    # Skip all functions that are on the exclusions list
    if ($global:FunctionHelpTestExceptions -contains $commandName) { continue }

    # The module-qualified command fails on Microsoft.PowerShell.Archive cmdlets
    $Help = Get-Help $commandName -ErrorAction SilentlyContinue

	Describe "Test help for $commandName" {

		# If help is not found, synopsis in auto-generated help is the syntax diagram
		It "should not be auto-generated" -TestCases @{ Help = $Help } {
			$Help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
		}

		# Should be a description for every function
		It "gets description for $commandName" -TestCases @{ Help = $Help } {
			$Help.Description | Should -Not -BeNullOrEmpty
		}

		# Should be at least one example
		It "gets example code from $commandName" -TestCases @{ Help = $Help } {
			($Help.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
		}

		# Should be at least one example description
		It "gets example help from $commandName" -TestCases @{ Help = $Help } {
			($Help.Examples.Example.Remarks | Select-Object -First 1).Text | Should -Not -BeNullOrEmpty
		}

        Context "Test parameter help for $commandName" {

            $common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable', 'Verbose', 'WarningAction', 'WarningVariable'

            $parameters = $command.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object Name -notin $common
            $parameterNames = $parameters.Name
            $HelpParameterNames = $Help.Parameters.Parameter.Name | Sort-Object -Unique
            foreach ($parameter in $parameters) {
                $parameterName = $parameter.Name
                $parameterHelp = $Help.parameters.parameter | Where-Object Name -EQ $parameterName

				# Should be a description for every parameter
				It "gets help for parameter: $parameterName : in $commandName" -TestCases @{ parameterHelp = $parameterHelp } {
					$parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
				}

                It "help for $parameterName parameter in $commandName has correct Mandatory value" -TestCases @{ parameterHelp = $parameterHelp; parameterName = $parameterName; command = $command } {
					($parameterHelp.Required -eq "true") | Should -BeIn $command.ParameterSets.parameters.Where{ $_.Name -eq $parameterName }.IsMandatory
				}

                if ($HelpTestSkipParameterType[$commandName] -contains $parameterName) { continue }

                $codeType = $parameter.ParameterType.Name

                if ($parameter.ParameterType.IsEnum) {
                    # Enumerations often have issues with the typename not being reliably available
                    $names = $parameter.ParameterType::GetNames($parameter.ParameterType)
						# Parameter type in Help should match code
					It "help for $commandName has correct parameter type for $parameterName" -TestCases @{ parameterHelp = $parameterHelp; names = $names } {
						$parameterHelp.parameterValueGroup.parameterValue | Should -be $names
					}
                }
                elseif ($parameter.ParameterType.FullName -in $HelpTestEnumeratedArrays) {
                    # Enumerations often have issues with the typename not being reliably available
                    $names = [Enum]::GetNames($parameter.ParameterType.DeclaredMembers[0].ReturnType)
					It "help for $commandName has correct parameter type for $parameterName" -TestCases @{ parameterHelp = $parameterHelp; names = $names } {
						$parameterHelp.parameterValueGroup.parameterValue | Should -be $names
					}
                }
                else {
                    # To avoid calling Trim method on a null object.
                    $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
					# Parameter type in Help should match code
					It "help for $commandName has correct parameter type for $parameterName" -TestCases @{ helpType = $helpType; codeType = $codeType } {
						$helpType | Should -be $codeType
					}
                }
            }
            foreach ($helpParm in $HelpParameterNames) {
				# Shouldn't find extra parameters in help.
				It "finds help parameter in code: $helpParm" -TestCases @{ helpParm = $helpParm; parameterNames = $parameterNames } {
					$helpParm -in $parameterNames | Should -Be $true
				}
            }
        }
    }
}
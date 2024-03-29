[CmdletBinding()]
Param (
	[switch]
	$SkipTest,

	[string[]]
	$CommandPath = @("$global:testroot\..\public", "$global:testroot\..\internal")
)

if ($SkipTest) { return }

$global:__pester_data.ScriptAnalyzer = New-Object System.Collections.ArrayList

Describe 'Invoking PSScriptAnalyzer against commandbase' {
	$commandFiles = foreach ($path in $CommandPath) { Get-ChildItem -Path $path -Recurse | Where-Object Name -like "*.ps1" }
	$scriptAnalyzerRules = Get-ScriptAnalyzerRule

	foreach ($file in $commandFiles)
	{
		Context "Analyzing $($file.BaseName)" {
			$analysis = Invoke-ScriptAnalyzer -Path $file.FullName -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess

			forEach ($rule in $scriptAnalyzerRules)
			{
				It "Should pass $rule" -TestCases @{ analysis = $analysis; rule = $rule } {
					If ($analysis.RuleName -contains $rule)
					{
						$analysis | Where-Object RuleName -EQ $rule -outvariable failures | ForEach-Object { $null = $global:__pester_data.ScriptAnalyzer.Add($_) }

						1 | Should -Be 0
					}
					else
					{
						0 | Should -Be 0
					}
				}
			}
		}
	}
}
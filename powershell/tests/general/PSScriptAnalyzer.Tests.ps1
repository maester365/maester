[CmdletBinding()]
Param (
    [switch]
    $SkipTest,

    [string[]]
    $CommandPath = @("$PSScriptRoot/../../public/", "$PSScriptRoot/../../internal/")
)

if ($SkipTest) { return }

$global:__pester_data.ScriptAnalyzer = New-Object System.Collections.ArrayList

Describe 'Invoking PSScriptAnalyzer against commandbase' {
    BeforeDiscovery {
        $commandFiles = Get-ChildItem -Path $CommandPath -Recurse -File -Filter '*.ps1'
        $scriptAnalyzerRules = Get-ScriptAnalyzerRule
    }

    Context 'Analyzing <_.BaseName>' -ForEach $commandFiles {
        BeforeAll {
            $file = $_
            $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess
        }
        It "Should pass '<_.RuleName>'" -ForEach $scriptAnalyzerRules {
            $rule = $_
            If ($analysis.RuleName -contains $rule.RuleName) {
                $analysis | Where-Object RuleName -EQ $rule -OutVariable failures | ForEach-Object { $null = $global:__pester_data.ScriptAnalyzer.Add($_) }
                1 | Should -Be 0
            }
        }
    }
}
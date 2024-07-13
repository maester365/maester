[CmdletBinding()]
Param (
    [switch]
    $SkipTest,

    [string[]]
    $CommandPath = @("$PSScriptRoot/../../public/", "$PSScriptRoot/../../internal/")
)

if ($SkipTest) { return }

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
        It "Should pass '<_.RuleName>'" -Tag 'ScriptAnalyzerRule' -ForEach $scriptAnalyzerRules {
            $rule = $_
            If ($analysis.RuleName -contains $rule.RuleName) {
                $failedRule = $analysis | Where-Object RuleName -EQ $rule.RuleName
                $failedRule # Intentional output so we can get it from StandardOutput-property in pester.ps1

                $failedRule | Should -BeNullOrEmpty
            }
        }
    }
}
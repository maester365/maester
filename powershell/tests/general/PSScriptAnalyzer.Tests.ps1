# PSScriptAnalyzer doesn't understand parameter is used in BeforeDiscovery
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'CommandPath')]
Param (
    [switch]
    $SkipTest,

    [string[]]
    $CommandPath = @("$PSScriptRoot/../../public/", "$PSScriptRoot/../../internal/", "$PSScriptRoot/../../tests/")
)

if ($SkipTest) { return }

BeforeDiscovery {
    # PSScriptAnalyzer doesn't understand these are used in ForEach data
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'commandFiles')]
    $commandFiles = Get-ChildItem -Path $CommandPath -Recurse -File -Filter '*.ps1'
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'scriptAnalyzerRules')]
    $scriptAnalyzerRules = Get-ScriptAnalyzerRule
}

Describe 'Invoking PSScriptAnalyzer against commandbase' -ForEach @{ commandFiles = $commandFiles; scriptAnalyzerRules = $scriptAnalyzerRules } {
    BeforeAll {
        # PSScriptAnalyzer doesn't understand this is used in nested contexts
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'analysis')]
        $analysis = $commandFiles | Invoke-ScriptAnalyzer -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess
    }

    # The next Context blocks are kinda duplicate, but helps us document both
    # which files and which rules where evaluated without running every rule for every file
    Context 'Analyzing rule <_.RuleName>' -ForEach $scriptAnalyzerRules {
        It 'All files should be compliant' {
            $failedFiles = foreach ($failure in $analysis) {
                if ($failure.RuleName -eq $_.RuleName) {
                    $failure.ScriptPath
                }
            }
            $failedFiles | Should -BeNullOrEmpty
        }
    }

    Context 'Analyzing file <_.BaseName>' -ForEach $commandFiles {
        It "Should pass all rules" -Tag 'ScriptAnalyzerRule' {
            $failedRules = foreach ($failure in $analysis) {
                if ($failure.ScriptPath -eq $_.FullName) {
                    $failure
                }
            }
            $failedRules # Intentional output so we can get it from StandardOutput-property in pester.ps1
            @($failedRules).RuleName | Should -BeNullOrEmpty
        }
    }
}

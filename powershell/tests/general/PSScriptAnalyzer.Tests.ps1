Param (
    [switch]
    $SkipTest,

    [string[]]
    $CommandPath = @("$PSScriptRoot/../../public/", "$PSScriptRoot/../../internal/")
)

if ($SkipTest) { return }

BeforeDiscovery {
    $commandFiles = Get-ChildItem -Path $CommandPath -Recurse -File -Filter '*.ps1'
    $scriptAnalyzerRules = Get-ScriptAnalyzerRule
}

Describe 'Invoking PSScriptAnalyzer against commandbase' -ForEach @{ commandFiles = $commandFiles } {
    BeforeAll {
        # Invoke-ScriptAnalyzer leaves a RunspacePool open for the life of the process. If pwsh exits just as
        # that pool's 15-minute idle-cleanup timer fires, PowerShell crashes with a NullReferenceException in
        # RunspacePoolInternal.DestroyRunspace. Analysing in a job keeps the pool out of the test process.
        $files = [string[]]$commandFiles.FullName
        $script:analysis = Start-Job -ScriptBlock {
            $using:files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess }
        } | Receive-Job -Wait -AutoRemoveJob
    }

    # The next Context blocks are kinda duplicate, but helps us document both
    # which files and which rules where evaluated without running every rule for every file
    Context 'Analyzing rule <_.RuleName>' -ForEach $scriptAnalyzerRules {
        BeforeAll {
            $rule = $_
        }
        It 'All files should be compliant' {
            $failedFiles = foreach ($failure in $script:analysis) {
                if ($failure.RuleName -eq $rule.RuleName) {
                    $failure.ScriptPath
                }
            }
            $failedFiles | Should -BeNullOrEmpty
        }
    }

    Context 'Analyzing file <_.BaseName>' -ForEach $commandFiles {
        BeforeAll {
            $file = $_
        }
        It "Should pass all rules" -Tag 'ScriptAnalyzerRule' {
            $failedRules = foreach ($failure in $script:analysis) {
                if ($failure.ScriptPath -eq $file.FullName) {
                    $failure
                }
            }
            $failedRules # Intentional output so we can get it from StandardOutput-property in pester.ps1
            @($failedRules).RuleName | Should -BeNullOrEmpty
        }
    }
}

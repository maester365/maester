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
        # The files are split over a few jobs, as each job is its own process: Invoke-ScriptAnalyzer is not
        # thread-safe, so ForEach-Object -Parallel in one process fails.
        $files = [string[]]$commandFiles.FullName
        $jobCount = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
        $jobs = for ($j = 0; $j -lt $jobCount; $j++) {
            $chunk = [string[]]@(for ($i = $j; $i -lt $files.Count; $i += $jobCount) { $files[$i] })
            Start-Job -ScriptBlock {
                $using:chunk | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess }
            }
        }
        # A job that fails only writes an error, which would leave its files unanalysed and the tests passing.
        $failedJobs = @($jobs | Wait-Job | Where-Object State -ne 'Completed')
        $script:analysis = $jobs | Receive-Job -Wait -AutoRemoveJob
        if ($failedJobs) { throw "ScriptAnalyzer job(s) did not complete: $($failedJobs.Name -join ', ')" }
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

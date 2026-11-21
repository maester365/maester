# $CommandPath is read in BeforeDiscovery, which runs before the analyzer's scope analysis and
# which it does not follow, so it reports the parameter as unused. Suppressed with the reason
# rather than renamed, since renaming would break anyone passing it.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'CommandPath',
    Justification = 'Consumed by Get-ChildItem in BeforeDiscovery, which the analyzer does not follow.')]
Param (
    [switch]
    $SkipTest,

    [string[]]
    $CommandPath = @(
        "$PSScriptRoot/../../public/",
        "$PSScriptRoot/../../internal/",
        # The analyzed set used to be the module's public and internal commands only, which is a
        # quarter of the PowerShell in the tree. The shipped tests and the unit tests were never
        # analyzed, so a rule could be green while the files users actually run went unchecked.
        "$PSScriptRoot/../../../tests/",
        "$PSScriptRoot/../"
    )
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
                # Rules that describe how a *command* should be written and do not apply to test code.
                # Excluded only under a test path, so the module's own commands keep being held to them:
                #   PSReviewUnusedParameter                     a Pester mock declares the parameters it
                #                                               filters on, and uses the ones it needs
                #   PSUseDeclaredVarsMoreThanAssignments        BeforeDiscovery variables are consumed by
                #                                               -ForEach at discovery, which it cannot see
                #   PSUseShouldProcessForStateChangingFunctions fixture builders named New-* build objects
                #                                               in memory and change no system state
                #   PSAvoidAssignmentToAutomaticVariable        $input as the name of a test's input fixture
                #   PSUseSingularNouns                          would mean renaming shipped test functions
                #                                               such as Test-MtCisGuestAccessReviews
                #   PSAvoidUsingWriteHost                       pester.ps1 is the runner; its output is for
                #                                               a person reading a console
                #   PSAvoidUsingPlainTextForPassword            fires on $PasswordValidityPeriodInDays,
                #                                               which is a number of days
                $soloPruebas = @(
                    'PSReviewUnusedParameter'
                    'PSUseDeclaredVarsMoreThanAssignments'
                    'PSUseShouldProcessForStateChangingFunctions'
                    'PSAvoidAssignmentToAutomaticVariable'
                    'PSUseSingularNouns'
                    'PSAvoidUsingWriteHost'
                    'PSAvoidUsingPlainTextForPassword'
                )
                $using:chunk | ForEach-Object {
                    $exclude = @('PSAvoidTrailingWhitespace', 'PSShouldProcess')
                    if ($_ -match '[\\/](tests)[\\/]') { $exclude += $soloPruebas }
                    Invoke-ScriptAnalyzer -Path $_ -ExcludeRule $exclude
                }
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

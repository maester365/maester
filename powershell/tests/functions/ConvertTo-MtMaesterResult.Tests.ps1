BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'ConvertTo-MtMaesterResult' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.TestResultDetail = @{}
            $__MtSession.MaesterConfig = [PSCustomObject]@{
                GlobalSettings   = [PSCustomObject]@{}
                TestSettings     = @()
                TestSettingsHash = @{}
            }
        }
        Mock Test-MtConnection -ModuleName Maester { $false }
        Mock Get-MtModuleVersion -ModuleName Maester { '0.0.0-test' }
        Mock Get-MtLatestModuleVersion -ModuleName Maester { $null }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.TestResultDetail = @{}
            $__MtSession.MaesterConfig = $null
        }
    }

    It 'Converts GitHub manual-review details to Investigate instead of Skipped' {
        InModuleScope Maester {
            $testName = 'CIS.GH.1.2.3: Ensure repository deletion is limited to specific users'
            $__MtSession.TestResultDetail[$testName] = @{
                TestTitle       = $testName
                TestDescription = 'GitHub repository deletion control.'
                TestResult      = 'Manual review required - members_can_delete_repositories is true.'
                TestSkipped     = $null
                SkippedReason   = $null
                TestInvestigate = $true
                Severity        = 'High'
                Service         = 'GitHub'
            }

            $pesterTest = [PSCustomObject]@{
                ExpandedName = $testName
                Result       = 'Passed'
                ErrorRecord  = @()
                ScriptBlock  = [scriptblock]::Create('$result = Test-MtCisGitHubRepositoryDeletionLimited')
                Block        = [PSCustomObject]@{
                    Tag          = @('CIS.GH.1.2.3', 'CIS GH')
                    ExpandedName = 'CIS'
                }
                Duration     = [TimeSpan]::FromSeconds(1)
                Tag          = @('CIS.GH.1.2.3')
            }
            $pesterResults = [PSCustomObject]@{
                Tests             = @($pesterTest)
                Containers        = @(
                    [PSCustomObject]@{
                        Blocks = @(
                            [PSCustomObject]@{
                                Name   = 'CIS'
                                Result = 'Passed'
                                Tag    = @('CIS')
                            }
                        )
                    }
                )
                Result            = 'Passed'
                ExecutedAt        = [DateTime]::UtcNow
                Duration          = [TimeSpan]::FromSeconds(1)
                UserDuration      = [TimeSpan]::FromSeconds(1)
                DiscoveryDuration = [TimeSpan]::Zero
                FrameworkDuration = [TimeSpan]::Zero
            }

            $result = ConvertTo-MtMaesterResult -PesterResults $pesterResults

            $result.Tests[0].Result | Should -Be 'Investigate'
            $result.InvestigateCount | Should -Be 1
            $result.SkippedCount | Should -Be 0
            $result.Tests[0].ResultDetail.TestResult | Should -Match 'Manual review required'
        }
    }
}

Describe 'Entra Connect Sync accidental deletion prevention (MT.1266)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the agent tests do.
        Use-MtModuleFunction -Name Test-MtEntraIDConnectSyncAccidentalDeletionPrevention

        function New-SyncConfig {
            param($Type, $Threshold)
            [pscustomobject]@{
                id            = 'sync-1'
                configuration = [pscustomobject]@{
                    accidentalDeletionPrevention = [pscustomobject]@{
                        synchronizationPreventionType = $Type
                        alertThreshold                = $Threshold
                    }
                }
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
        }
        Mock -ModuleName Maester Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated' } }
        Mock -ModuleName Maester Invoke-MtGraphRequest { [pscustomobject]@{ onPremisesSyncEnabled = $true } } -ParameterFilter {
            $RelativeUri -eq 'organization'
        }
    }

    AfterEach {
        # Result text must not contain backtick-wrapped code spans (repo result-text lint).
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    It 'passes when prevention is enabled for a count' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { New-SyncConfig 'enabledForCount' 500 } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        $script:TestResult | Should -Match '500'
    }

    It 'passes when prevention is enabled for a percentage' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { New-SyncConfig 'enabledForPercentage' 10 } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeTrue
        $script:TestResult | Should -Match '10 %'
    }

    It 'fails when prevention is disabled' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { New-SyncConfig 'disabled' 0 } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeFalse
        $script:TestResult | Should -Match 'disabled'
    }

    It 'fails when the setting is missing (must not be treated as enabled)' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { [pscustomobject]@{ id = 'sync-1'; configuration = $null } } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeFalse
        $script:TestResult | Should -Match 'not set'
    }

    It 'skips as NotApplicable when the tenant does not synchronize' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { [pscustomobject]@{ onPremisesSyncEnabled = $null } } -ParameterFilter {
            $RelativeUri -eq 'organization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotApplicable'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }
    }

    It 'skips as NotSupportedAppPermission with an application connection' {
        Mock -ModuleName Maester Get-MgContext { [pscustomobject]@{ AuthType = 'AppOnly' } }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotSupportedAppPermission'
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        Test-MtEntraIDConnectSyncAccidentalDeletionPrevention | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' } -ParameterFilter {
            $RelativeUri -eq 'directory/onPremisesSynchronization'
        }

        { Test-MtEntraIDConnectSyncAccidentalDeletionPrevention } | Should -Throw '*Service unavailable*'
    }
}

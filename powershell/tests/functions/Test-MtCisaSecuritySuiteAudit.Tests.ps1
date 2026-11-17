BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.5.2.ps1')
}

Describe 'CISA Security Suite audit retention check' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        $script:exoResponses = @{
            UnifiedAuditLogRetentionPolicy = @(
                [pscustomobject]@{
                    Enabled = $true
                    RecordTypes = @('ExchangeAdmin', 'ExchangeItem', 'ExchangeItemGroup', 'ExchangeAggregatedOperation', 'ExchangeItemAggregated')
                    RetentionDuration = 'TwelveMonths'
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }
    }

    It 'reports Exchange retention evidence as requiring manual verification of the full requirement' {
        $result = Test-MtCisaAuditLogRetention
        $result | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
            $Investigate -and $Result -match 'cannot verify the full requirement' -and $Result -match 'does not assess the user scope'
        }
    }

    It 'keeps the result investigatory when no qualifying Exchange retention policy is found' {
        $script:exoResponses.UnifiedAuditLogRetentionPolicy[0].RetentionDuration = 'SixMonths'

        $result = Test-MtCisaAuditLogRetention
        $result | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
            $Investigate -and $Result -match 'Other approved retention or log-export solutions may still satisfy'
        }
    }

    It 'reports manual review when no Exchange retention policy is returned' {
        $script:exoResponses.UnifiedAuditLogRetentionPolicy = @()

        $result = Test-MtCisaAuditLogRetention
        $result | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate }
    }

    It 'keeps manual review available and includes the error when the optional policy lookup fails' {
        Mock Get-MtExo { throw 'Retention policy lookup unavailable.' }

        $result = Test-MtCisaAuditLogRetention
        $result | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
            $Investigate -and $Result -match 'evidence could not be retrieved. Retention policy lookup unavailable'
        }
    }
}

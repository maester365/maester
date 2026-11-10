BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    function Get-TestSensitiveDlpResponse {
        $advancedRule = @(
            '50842eb7-edc8-4019-85dd-5a5c1f2bb085',
            'a44669fe-0d48-453d-a9b1-2cc83f2cba77',
            'e55e2a32-f92d-4985-a35d-a0b269eb687b'
        ) -join ' '

        @{
            DlpCompliancePolicy = @(
                [pscustomobject]@{
                    Name = 'Sensitive information'; Identity = 'Sensitive information'; Enabled = $true
                    Mode = 'Enable'
                    Workload = @('Exchange', 'OneDriveForBusiness', 'SharePoint', 'Teams', 'EndpointDevices')
                    ExchangeLocation = @([pscustomobject]@{ DisplayName = 'All' })
                    OneDriveLocation = @([pscustomobject]@{ DisplayName = 'All' })
                    SharePointLocation = @([pscustomobject]@{ DisplayName = 'All' })
                    TeamsLocation = @([pscustomobject]@{ DisplayName = 'All' })
                    EndpointDlpLocation = @([pscustomobject]@{ DisplayName = 'All' })
                }
            )
            DlpComplianceRule = @(
                [pscustomobject]@{
                    Name = 'Protect sensitive information'; ParentPolicyName = 'Sensitive information'
                    Disabled = $false; IsAdvancedRule = $true; Mode = 'Enforce'; AdvancedRule = $advancedRule
                    ContentContainsSensitiveInformation = @()
                    BlockAccess = $true; BlockAccessScope = 'All'; NotifyUser = @('user@contoso.com')
                }
            )
        }
    }

    . (Join-Path $testRoot 'powershell\internal\checks\cisa\purview\Get-MtCisaSensitiveDlpRule.ps1')
    . (Join-Path $testRoot 'tests\cisa\purview\Test.CISA.MS.SECURITYSUITE.3.1.ps1')
    . (Join-Path $testRoot 'tests\cisa\purview\Test.CISA.MS.SECURITYSUITE.3.2.ps1')
    . (Join-Path $testRoot 'tests\cisa\purview\Test.CISA.MS.SECURITYSUITE.3.3.ps1')
    . (Join-Path $testRoot 'tests\cisa\purview\Test.CISA.MS.SECURITYSUITE.3.4.ps1')
    . (Join-Path $testRoot 'tests\cisa\purview\Test.CISA.MS.SECURITYSUITE.3.5.ps1')
}

Describe 'CISA Security Suite Purview checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }
    It 'checks that sensitive-information DLP policies cover all five workloads' {
        $script:exoResponses = Get-TestSensitiveDlpResponse
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpLocationCoverage | Should -BeTrue

        $script:exoResponses.DlpCompliancePolicy[0].TeamsLocation = @()
        Test-MtCisaDlpLocationCoverage | Should -BeFalse
    }

    It 'recognizes basic DLP sensitive-information types and requires an enabled parent policy' {
        $script:exoResponses = Get-TestSensitiveDlpResponse
        $script:exoResponses.DlpComplianceRule[0].IsAdvancedRule = $false
        $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation = @(
            [pscustomobject]@{ Name = 'Credit Card Number' }
            [pscustomobject]@{ Name = 'U.S. Social Security Number (SSN)' }
            [pscustomobject]@{ Name = 'U.S. Individual Taxpayer Identification Number (ITIN)' }
        )
        $script:exoResponses.DlpComplianceRule[0].AdvancedRule = $null
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpSensitiveInformation | Should -BeTrue
        Test-MtCisaDlpLocationCoverage | Should -BeTrue
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeTrue
        Test-MtCisaDlpUserNotification | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation = @(
            $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation | Select-Object -First 2
        )
        Test-MtCisaDlpSensitiveInformation | Should -BeFalse
        Test-MtCisaDlpLocationCoverage | Should -BeFalse
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeFalse
        Test-MtCisaDlpUserNotification | Should -BeFalse

        $script:exoResponses = Get-TestSensitiveDlpResponse
        $script:exoResponses.DlpCompliancePolicy[0].Mode = 'Audit'
        Test-MtCisaDlpSensitiveInformation | Should -BeFalse
        Test-MtCisaDlpLocationCoverage | Should -BeFalse
    }

    It 'requires full-protection DLP rules to block access for everyone' {
        $script:exoResponses = Get-TestSensitiveDlpResponse
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].BlockAccessScope = 'NotInvolved'
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeFalse
    }

    It 'requires full-protection DLP rules to notify at least one user' {
        $script:exoResponses = Get-TestSensitiveDlpResponse
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpUserNotification | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].NotifyUser = @()
        Test-MtCisaDlpUserNotification | Should -BeFalse
    }

    It 'returns an investigation result for the manual endpoint DLP requirement' {
        Test-MtCisaDlpEndpointRestriction | Should -BeTrue

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate }
    }

    It 'aggregates types across rules only under enabled parent policies' {
        $script:exoResponses = Get-TestSensitiveDlpResponse
        $script:exoResponses.DlpComplianceRule = @(
            [pscustomobject]@{
                Name = 'Credit card'; ParentPolicyName = 'Sensitive information'; Disabled = $false
                IsAdvancedRule = $true; AdvancedRule = '50842eb7-edc8-4019-85dd-5a5c1f2bb085'
            }
            [pscustomobject]@{
                Name = 'SSN'; ParentPolicyName = 'Sensitive information'; Disabled = $false
                IsAdvancedRule = $true; AdvancedRule = 'a44669fe-0d48-453d-a9b1-2cc83f2cba77'
            }
            [pscustomobject]@{
                Name = 'Unrelated ITIN'; ParentPolicyName = 'Other policy'; Disabled = $false
                IsAdvancedRule = $true; AdvancedRule = 'e55e2a32-f92d-4985-a35d-a0b269eb687b'
            }
        )
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpSensitiveInformation | Should -BeFalse

        $script:exoResponses.DlpComplianceRule[2].ParentPolicyName = 'Sensitive information'
        Test-MtCisaDlpSensitiveInformation | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[1].Disabled = $true
        Test-MtCisaDlpSensitiveInformation | Should -BeFalse

        $script:exoResponses.DlpComplianceRule[1].Disabled = $false

        $script:exoResponses.DlpCompliancePolicy[0].Mode = 'Audit'
        Test-MtCisaDlpSensitiveInformation | Should -BeFalse
    }
}

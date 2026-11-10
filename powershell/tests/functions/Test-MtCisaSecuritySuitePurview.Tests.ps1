BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    function New-TestSensitiveDlpResponses {
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
        $script:exoResponses = New-TestSensitiveDlpResponses
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpAllLocations | Should -BeTrue

        $script:exoResponses.DlpCompliancePolicy[0].TeamsLocation = @()
        Test-MtCisaDlpAllLocations | Should -BeFalse
    }

    It 'recognizes basic DLP sensitive-information types and requires an enabled parent policy' {
        $script:exoResponses = New-TestSensitiveDlpResponses
        $script:exoResponses.DlpComplianceRule[0].IsAdvancedRule = $false
        $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation = @(
            [pscustomobject]@{ Name = 'Credit Card Number' }
            [pscustomobject]@{ Name = 'U.S. Social Security Number (SSN)' }
            [pscustomobject]@{ Name = 'U.S. Individual Taxpayer Identification Number (ITIN)' }
        )
        $script:exoResponses.DlpComplianceRule[0].AdvancedRule = $null
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpAllLocations | Should -BeTrue
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeTrue
        Test-MtCisaDlpNotifiesUsers | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation = @(
            $script:exoResponses.DlpComplianceRule[0].ContentContainsSensitiveInformation | Select-Object -First 2
        )
        Test-MtCisaDlpAllLocations | Should -BeFalse
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeFalse
        Test-MtCisaDlpNotifiesUsers | Should -BeFalse

        $script:exoResponses = New-TestSensitiveDlpResponses
        $script:exoResponses.DlpCompliancePolicy[0].Mode = 'Audit'
        Test-MtCisaDlpAllLocations | Should -BeFalse
    }

    It 'requires full-protection DLP rules to block access for everyone' {
        $script:exoResponses = New-TestSensitiveDlpResponses
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].BlockAccessScope = 'NotInvolved'
        Test-MtCisaDlpBlocksSensitiveInformation | Should -BeFalse
    }

    It 'requires full-protection DLP rules to notify at least one user' {
        $script:exoResponses = New-TestSensitiveDlpResponses
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaDlpNotifiesUsers | Should -BeTrue

        $script:exoResponses.DlpComplianceRule[0].NotifyUser = @()
        Test-MtCisaDlpNotifiesUsers | Should -BeFalse
    }

    It 'returns an investigation result for the manual endpoint DLP requirement' {
        Test-MtCisaDlpEndpointRestrictions | Should -BeTrue

        Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate }
    }
}

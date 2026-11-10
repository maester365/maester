BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.7.1.ps1')
}
Describe 'CISA Security Suite Safe Links checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'requires the effective Safe Links policy to protect all channels and internal senders' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; RecommendedPolicyType = 'Strict'
                    EnableSafeLinksForEmail = $true; EnableSafeLinksForTeams = $true
                    EnableSafeLinksForOffice = $true; EnableForInternalSenders = $true
                }
            )
            EOPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; State = 'Enabled'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            SafeLinksRule = @()
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLink | Should -BeTrue

        $script:exoResponses.SafeLinksPolicy[0].EnableForInternalSenders = $false
        Test-MtCisaSafeLink | Should -BeFalse
    }

    It 'selects the highest-priority enabled Safe Links rule that covers all recipients' {
        $script:exoResponses = @{
            SafeLinksPolicy = @(
                [pscustomobject]@{
                    Identity = 'All recipients'; Name = 'All recipients'
                    EnableSafeLinksForEmail = $true; EnableSafeLinksForTeams = $true
                    EnableSafeLinksForOffice = $true; EnableForInternalSenders = $true
                }
            )
            EOPProtectionPolicyRule = @()
            SafeLinksRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 1; SafeLinksPolicy = 'Scoped'
                    SentTo = @('user@contoso.com'); SentToMemberOf = @(); RecipientDomainIs = @()
                },
                [pscustomobject]@{
                    State = 'Enabled'; Priority = 2; SafeLinksPolicy = 'All recipients'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSafeLink | Should -BeTrue
    }
}

BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.6.1.ps1')
}
Describe 'CISA Security Suite spam filter checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'uses active all-recipient spam-policy precedence and checks the strict preset first' {
        $script:exoResponses = @{
            HostedContentFilterPolicy = @(
                [pscustomobject]@{
                    Identity = 'Strict'; RecommendedPolicyType = 'Strict'; IsDefault = $false
                    SpamAction = 'Quarantine'; HighConfidenceSpamAction = 'Delete'
                    PhishSpamAction = 'Redirect'; HighConfidencePhishAction = 'MoveToJmf'
                },
                [pscustomobject]@{
                    Identity = 'Custom'; RecommendedPolicyType = 'Custom'; IsDefault = $false
                    SpamAction = 'Deliver'; HighConfidenceSpamAction = 'Deliver'
                    PhishSpamAction = 'Deliver'; HighConfidencePhishAction = 'Deliver'
                },
                [pscustomobject]@{
                    Identity = 'Default'; RecommendedPolicyType = 'Custom'; IsDefault = $true
                    SpamAction = 'Deliver'; HighConfidenceSpamAction = 'Deliver'
                    PhishSpamAction = 'Deliver'; HighConfidencePhishAction = 'Deliver'
                }
            )
            EOPProtectionPolicyRule = @(
                [pscustomobject]@{
                    Identity = 'Strict Preset Security Policy'; HostedContentFilterPolicy = 'Strict'
                    State = 'Enabled'; SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                }
            )
            HostedContentFilterRule = @(
                [pscustomobject]@{
                    Identity = 'Custom'; HostedContentFilterPolicy = 'Custom'; State = 'Enabled'
                    SentTo = @(); SentToMemberOf = @(); RecipientDomainIs = @()
                    ExceptIfSentTo = @(); ExceptIfSentToMemberOf = @(); ExceptIfRecipientDomainIs = @()
                }
            )
            AcceptedDomain = @()
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSpamAction | Should -BeTrue

        $script:exoResponses.HostedContentFilterPolicy[0].HighConfidencePhishAction = 'Deliver'
        Test-MtCisaSpamAction | Should -BeFalse
    }

    It 'checks the default spam policy when no higher-priority policy is compliant' {
        $script:exoResponses = @{
            HostedContentFilterPolicy = @(
                [pscustomobject]@{
                    Identity = 'Default'; RecommendedPolicyType = 'Custom'; IsDefault = $true
                    SpamAction = 'Deliver'; HighConfidenceSpamAction = 'Quarantine'
                    PhishSpamAction = 'Quarantine'; HighConfidencePhishAction = 'Quarantine'
                }
            )
            EOPProtectionPolicyRule = @()
            HostedContentFilterRule = @()
            AcceptedDomain = @()
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaSpamAction | Should -BeFalse

        $script:exoResponses.HostedContentFilterPolicy[0].SpamAction = 'Delete'
        Test-MtCisaSpamAction | Should -BeTrue
    }
}

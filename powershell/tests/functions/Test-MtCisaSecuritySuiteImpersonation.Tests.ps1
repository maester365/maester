BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.1.ps1')
    . (Join-Path $testRoot 'powershell\internal\checks\cisa\exchange\Get-MtCisaEffectiveAntiPhishPolicy.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.2.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.3.ps1')
}
Describe 'CISA Security Suite impersonation protection checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'requires at least one protected sensitive user for user impersonation protection' {
        $script:policies = @(
            [pscustomobject]@{
                Identity = 'Standard'; Guid = 'standard'; RecommendedPolicyType = 'Standard'; Enabled = $true
                ImpersonationProtectionState = 'Automatic'; EnableOrganizationDomainsProtection = $true
                EnableTargetedDomainsProtection = $true; EnableTargetedUserProtection = $true
                TargetedUsersToProtect = @('sensitive@example.com')
            },
            [pscustomobject]@{
                Identity = 'Strict'; Guid = 'strict'; RecommendedPolicyType = 'Strict'; Enabled = $true
                ImpersonationProtectionState = 'Automatic'; EnableOrganizationDomainsProtection = $true
                EnableTargetedDomainsProtection = $true; EnableTargetedUserProtection = $true
                TargetedUsersToProtect = @()
            }
        )
        Mock Get-MtExo { $script:policies }

        Test-MtCisaImpersonation | Should -BeTrue

        $script:policies[0].TargetedUsersToProtect = @()
        Test-MtCisaImpersonation | Should -BeFalse
    }

    It 'checks owned-domain impersonation protection on an effective all-recipient policy' {
        $script:exoResponses = @{
            AntiPhishPolicy = @(
                [pscustomobject]@{
                    Name = 'Default'; Identity = 'Default'; Enabled = $true; IsDefault = $true
                    EnableOrganizationDomainsProtection = $true; TargetedDomainProtectionAction = 'Quarantine'
                }
            )
            AntiPhishRule = @()
            EOPProtectionPolicyRule = @()
            AcceptedDomain = @([pscustomobject]@{ DomainName = 'contoso.com' })
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaOwnedDomainImpersonationProtection | Should -BeTrue

        $script:exoResponses.AntiPhishPolicy[0].TargetedDomainProtectionAction = 'BccMessage'
        Test-MtCisaOwnedDomainImpersonationProtection | Should -BeFalse
        $script:exoResponses.AntiPhishPolicy[0].TargetedDomainProtectionAction = 'MoveToJmf'
        Test-MtCisaOwnedDomainImpersonationProtection | Should -BeTrue

        $script:exoResponses.AntiPhishPolicy[0].TargetedDomainProtectionAction = 'Quarantine'
        $script:exoResponses.AntiPhishPolicy[0].EnableOrganizationDomainsProtection = $false
        Test-MtCisaOwnedDomainImpersonationProtection | Should -BeFalse
    }

    It 'does not treat a scoped custom anti-phish rule as covering all recipients' {
        $script:exoResponses = @{
            AntiPhishPolicy = @(
                [pscustomobject]@{
                    Name = 'Custom'; Identity = 'Custom'; Enabled = $true; IsDefault = $false
                    RecommendedPolicyType = 'Custom'; EnableOrganizationDomainsProtection = $true
                    TargetedDomainProtectionAction = 'Quarantine'
                }
            )
            AntiPhishRule = @(
                [pscustomobject]@{
                    State = 'Enabled'; AntiPhishPolicy = 'Custom'; SentTo = @('user@contoso.com')
                    SentToMemberOf = @(); RecipientDomainIs = @(); ExceptIfSentTo = @()
                    ExceptIfSentToMemberOf = @(); ExceptIfRecipientDomainIs = @()
                }
            )
            EOPProtectionPolicyRule = @()
            AcceptedDomain = @([pscustomobject]@{ DomainName = 'contoso.com' })
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaOwnedDomainImpersonationProtection | Should -BeFalse
    }

    It 'requires configured partner domains and protection for every configured domain' {
        $script:exoResponses = @{
            AntiPhishPolicy = @(
                [pscustomobject]@{
                    Name = 'Default'; Identity = 'Default'; Enabled = $true; IsDefault = $true
                    EnableTargetedDomainsProtection = $true; TargetedDomainProtectionAction = 'Quarantine'
                    TargetedDomainsToProtect = @('partner.example')
                }
            )
            AntiPhishRule = @()
            EOPProtectionPolicyRule = @()
            AcceptedDomain = @([pscustomobject]@{ DomainName = 'contoso.com' })
        }
        Mock Get-MtExo { $script:exoResponses[$Request] }

        Test-MtCisaPartnerDomainImpersonationProtection -PartnerDomains 'partner.example' | Should -BeTrue
        $script:exoResponses.AntiPhishPolicy[0].TargetedDomainProtectionAction = 'BccMessage'
        Test-MtCisaPartnerDomainImpersonationProtection -PartnerDomains 'partner.example' | Should -BeFalse
        $script:exoResponses.AntiPhishPolicy[0].TargetedDomainProtectionAction = 'MoveToJmf'
        Test-MtCisaPartnerDomainImpersonationProtection -PartnerDomains 'partner.example' | Should -BeTrue
        Test-MtCisaPartnerDomainImpersonationProtection | Should -BeFalse
        Test-MtCisaPartnerDomainImpersonationProtection -PartnerDomains @('partner.example', 'supplier.example') | Should -BeFalse
    }
}

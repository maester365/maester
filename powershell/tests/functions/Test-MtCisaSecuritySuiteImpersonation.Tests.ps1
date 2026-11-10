BeforeAll {
    $testRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.1.ps1')
    . (Join-Path $testRoot 'powershell\internal\checks\cisa\exchange\Get-MtCisaEffectiveAntiPhishPolicy.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.2.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.3.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.2.4.ps1')
    . (Join-Path $testRoot 'tests\cisa\exchange\Test.CISA.MS.SECURITYSUITE.4.1.ps1')
}
Describe 'CISA Security Suite impersonation protection checks' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'requires every configured sensitive user and an acceptable action' {
        $script:policies = @(
            [pscustomobject]@{
                Identity = 'Default'; EnableTargetedUserProtection = $true
                TargetedUserProtectionAction = 'Quarantine'
                TargetedUsersToProtect = @('Sensitive Person;sensitive@example.com', 'ADMIN@example.com')
            }
        )
        Mock Get-MtCisaEffectiveAntiPhishPolicy { $script:policies }

        Test-MtCisaImpersonation -SensitiveUsers @('sensitive@example.com', 'admin@example.com') | Should -BeTrue

        $script:policies[0].TargetedUsersToProtect = @('sensitive@example.com')
        Test-MtCisaImpersonation -SensitiveUsers @('sensitive@example.com', 'admin@example.com') | Should -BeFalse

        $script:policies[0].TargetedUsersToProtect = @('sensitive@example.com', 'admin@example.com')
        $script:policies[0].TargetedUserProtectionAction = 'BccMessage'
        Test-MtCisaImpersonation -SensitiveUsers @('sensitive@example.com', 'admin@example.com') | Should -BeFalse

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

    It 'checks all six safety tips on an all-recipient custom policy' {
        $script:effectivePolicies = @(
            [pscustomobject]@{
                Identity = 'Custom'
                EnableFirstContactSafetyTips = $true
                EnableSimilarUsersSafetyTips = $true
                EnableSimilarDomainsSafetyTips = $true
                EnableUnusualCharactersSafetyTips = $true
                EnableViaTag = $true
                EnableUnauthenticatedSender = $true
            }
        )
        Mock Get-MtCisaEffectiveAntiPhishPolicy { $script:effectivePolicies }

        Test-MtCisaImpersonationTip | Should -BeTrue

        foreach ($tip in @(
                'EnableFirstContactSafetyTips',
                'EnableSimilarUsersSafetyTips',
                'EnableSimilarDomainsSafetyTips',
                'EnableUnusualCharactersSafetyTips',
                'EnableViaTag',
                'EnableUnauthenticatedSender'
            )) {
            $script:effectivePolicies[0].$tip = $false
            Test-MtCisaImpersonationTip | Should -BeFalse
            $script:effectivePolicies[0].$tip = $true
        }
    }

    It 'accepts an all-recipient preset policy for user safety tips' {
        Mock Get-MtCisaEffectiveAntiPhishPolicy {
            @([pscustomobject]@{ Identity = 'Standard Preset Security Policy' })
        }

        Test-MtCisaImpersonationTip | Should -BeTrue
    }

    It 'requires baseline alerts to be enabled and includes the URL-click alert when present' {
        $alertNames = @(
            'Suspicious email sending patterns detected',
            'Suspicious connector activity',
            'Suspicious Email Forwarding Activity',
            'Messages have been delayed',
            'Tenant restricted from sending unprovisioned email',
            'Tenant restricted from sending email'
        )
        $script:alerts = @(
            foreach ($alertName in $alertNames) {
                [pscustomobject]@{ Name = $alertName; Disabled = $false; NotificationEnabled = $false }
            }
        )
        Mock Get-MtExo { $script:alerts }

        Test-MtCisaExoAlert | Should -BeTrue

        $script:alerts[0].Disabled = $true
        Test-MtCisaExoAlert | Should -BeFalse
        $script:alerts[0].Disabled = $false

        $script:alerts += [pscustomobject]@{
            Name = 'A potentially malicious URL click was detected'
            Disabled = $true
            NotificationEnabled = $true
        }
        Test-MtCisaExoAlert | Should -BeFalse

        $script:alerts[-1].Disabled = $false
        Test-MtCisaExoAlert | Should -BeTrue
    }
}

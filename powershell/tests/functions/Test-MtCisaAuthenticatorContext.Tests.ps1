BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name @(
        'Test-MtCisaAuthenticatorContext',
        'Get-MtCisaPhishingResistantPolicy',
        'Test-MtCisaPhishResistant'
    )

    function Get-TestPhishingResistantPolicy {
        [pscustomobject]@{
            state = 'enabled'
            conditions = [pscustomobject]@{
                applications = [pscustomobject]@{
                    includeApplications = @('All')
                    excludeApplications = @()
                }
                users = [pscustomobject]@{
                    includeUsers = @('All')
                    excludeUsers = @()
                    excludeGroups = @()
                    excludeRoles = @()
                    excludeGuestsOrExternalUsers = $null
                }
            }
            grantControls = [pscustomobject]@{
                authenticationStrength = [pscustomobject]@{
                    id = 'custom'
                    allowedCombinations = @('fido2', 'windowsHelloForBusiness')
                }
            }
        }
    }
}

Describe 'CISA Microsoft Authenticator context and software OTP' {
    BeforeEach {
        $script:ResultMarkdown = $null
        $script:SkippedBecause = $null
        $script:ConditionalAccessPolicies = @()
        $script:AuthenticatorPolicy = [pscustomobject]@{
            id = 'MicrosoftAuthenticator'
            state = 'enabled'
            includeTargets = @(@{ id = 'all_users' })
            isSoftwareOathEnabled = $false
            featureSettings = @{
                displayAppInformationRequiredState = @{ state = 'enabled'; includeTarget = @{ id = 'all_users' } }
                displayLocationInformationRequiredState = @{ state = 'enabled'; includeTarget = @{ id = 'all_users' } }
            }
        }
        Mock -ModuleName Maester Get-MtAuthenticationMethodPolicyConfig {
            @(
                $script:AuthenticatorPolicy
                [pscustomobject]@{ id = 'Email'; state = 'enabled' }
            )
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            $script:ConditionalAccessPolicies
        }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)
            $script:ResultMarkdown = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'skips when the Microsoft Authenticator policy is disabled' {
        $script:AuthenticatorPolicy.state = 'disabled'

        Test-MtCisaAuthenticatorContext | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotApplicable'
    }

    It 'skips when no Microsoft Authenticator policy is returned' {
        $script:AuthenticatorPolicy = $null

        Test-MtCisaAuthenticatorContext | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotApplicable'
    }

    It 'skips when ScubaGear would mark phishing-resistant MFA as enforced' {
        $script:ConditionalAccessPolicies = @(Get-TestPhishingResistantPolicy)

        Test-MtCisaAuthenticatorContext | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotApplicable'
        Get-MtCisaPhishingResistantPolicy | Should -HaveCount 1
        Test-MtCisaPhishResistant | Should -BeTrue
    }

    It 'does not skip when a phishing-resistant policy has role exclusions' {
        $policy = Get-TestPhishingResistantPolicy
        $policy.conditions.users.excludeRoles = @('Global Administrator')
        $script:ConditionalAccessPolicies = @($policy)

        Test-MtCisaAuthenticatorContext | Should -BeTrue
        $script:SkippedBecause | Should -BeNullOrEmpty
        Get-MtCisaPhishingResistantPolicy | Should -BeNullOrEmpty
    }

    It 'does not skip when a phishing-resistant policy excludes users, groups, apps, or guests' {
        $policy = Get-TestPhishingResistantPolicy
        $policy.conditions.users.excludeUsers = @('user-id')
        $policy.conditions.users.excludeGroups = @('group-id')
        $policy.conditions.applications.excludeApplications = @('app-id')
        $policy.conditions.users.excludeGuestsOrExternalUsers = [pscustomobject]@{
            guestOrExternalUserTypes = 'b2bCollaborationGuest'
        }
        $script:ConditionalAccessPolicies = @($policy)

        Test-MtCisaAuthenticatorContext | Should -BeTrue
        $script:SkippedBecause | Should -BeNullOrEmpty
        Get-MtCisaPhishingResistantPolicy | Should -BeNullOrEmpty
    }

    It 'does not skip when an authentication strength allows a non-phishing-resistant method' {
        $policy = Get-TestPhishingResistantPolicy
        $policy.grantControls.authenticationStrength.allowedCombinations = @('fido2', 'password,sms')
        $script:ConditionalAccessPolicies = @($policy)

        Test-MtCisaAuthenticatorContext | Should -BeTrue
        $script:SkippedBecause | Should -BeNullOrEmpty
        Get-MtCisaPhishingResistantPolicy | Should -BeNullOrEmpty
    }

    It 'does not skip when a phishing-resistant policy does not include all users' {
        $policy = Get-TestPhishingResistantPolicy
        $policy.conditions.users.includeUsers = @('group-id')
        $script:ConditionalAccessPolicies = @($policy)

        Test-MtCisaAuthenticatorContext | Should -BeTrue
        $script:SkippedBecause | Should -BeNullOrEmpty
        Get-MtCisaPhishingResistantPolicy | Should -BeNullOrEmpty
    }

    It 'passes with Authenticator software OTP disabled even when Email OTP is enabled' {
        Test-MtCisaAuthenticatorContext | Should -BeTrue
        $script:ResultMarkdown | Should -Match 'software OTP \(not Email OTP\) disabled'
    }

    It 'fails with Authenticator software OTP enabled despite both context settings being enabled' {
        $script:AuthenticatorPolicy.isSoftwareOathEnabled = $true

        Test-MtCisaAuthenticatorContext | Should -BeFalse
        $script:ResultMarkdown | Should -Match '\| Microsoft Authenticator software OTP \(not Email OTP\) disabled \| ❌ Fail \|'
    }

    It 'does not label missing Authenticator software OTP data as passing' {
        $script:AuthenticatorPolicy.isSoftwareOathEnabled = $null

        Test-MtCisaAuthenticatorContext | Should -BeFalse
        $script:ResultMarkdown | Should -Match '\| Microsoft Authenticator software OTP \(not Email OTP\) disabled \| ❌ Fail \|'
    }

    It 'still fails when application or location context is disabled' -ForEach @(
        @{ Setting = 'displayAppInformationRequiredState' }
        @{ Setting = 'displayLocationInformationRequiredState' }
    ) {
        $script:AuthenticatorPolicy.featureSettings[$Setting].state = 'disabled'

        Test-MtCisaAuthenticatorContext | Should -BeFalse
    }
}

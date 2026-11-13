BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisaAuthenticatorContext
}

Describe 'CISA Microsoft Authenticator context and software OTP' {
    BeforeEach {
        $script:ResultMarkdown = $null
        $script:SkippedBecause = $null
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

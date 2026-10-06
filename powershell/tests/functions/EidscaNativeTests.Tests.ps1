Describe 'EIDSCA native tests' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The generated [MaesterTest] functions are not exported.
        Use-MtModuleFunction -Name Test-MtCheckEidscaAP04, Test-MtCheckEidscaAP05, Test-MtCheckEidscaPR05,
        Test-MtCheckEidscaPR06, Test-MtCheckEidscaCR04, Test-MtCheckEidscaAF05

        # Tenant values returned by the mocked Graph requests, keyed by relative URI.
        $script:Graph = @{}
        $script:EnabledAuthMethods = @()
        Mock -ModuleName Maester Invoke-MtGraphRequest { $script:Graph[$RelativeUri] }
        Mock -ModuleName Maester Get-MtAuthenticationMethodPolicyConfig { $script:EnabledAuthMethods | ForEach-Object { [pscustomobject]@{ Id = $_ } } }
        Mock -ModuleName Maester Add-MtTestResultDetail {}

        function New-DirectorySetting {
            param([hashtable] $Values)
            [pscustomobject]@{ values = @($Values.GetEnumerator() | ForEach-Object { [pscustomobject]@{ name = $_.Key; value = $_.Value } }) }
        }
    }

    BeforeEach {
        $script:Graph = @{}
        $script:EnabledAuthMethods = @()
    }

    Context '-eq (EIDSCA.AP05)' {
        It 'passes when the tenant value equals the recommended value, ignoring case' {
            $script:Graph['policies/authorizationPolicy'] = [pscustomobject]@{ allowedToSignUpEmailBasedSubscriptions = $false }
            Test-MtCheckEidscaAP05 | Should -BeTrue
        }
        It 'fails when the tenant value differs' {
            $script:Graph['policies/authorizationPolicy'] = [pscustomobject]@{ allowedToSignUpEmailBasedSubscriptions = $true }
            Test-MtCheckEidscaAP05 | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -like 'Your tenant is configured as **True**.*' }
        }
    }

    Context '-in (EIDSCA.AP04)' {
        It 'passes when the tenant value is one of the recommended values' {
            $script:Graph['policies/authorizationPolicy'] = [pscustomobject]@{ allowInvitesFrom = 'none' }
            Test-MtCheckEidscaAP04 | Should -BeTrue
        }
        It 'fails when the tenant value is not one of them' {
            $script:Graph['policies/authorizationPolicy'] = [pscustomobject]@{ allowInvitesFrom = 'everyone' }
            Test-MtCheckEidscaAP04 | Should -BeFalse
        }
    }

    Context '-ge (EIDSCA.PR05)' {
        It 'passes at or above the threshold' {
            $script:Graph['settings'] = New-DirectorySetting @{ LockoutDurationInSeconds = '60' }
            Test-MtCheckEidscaPR05 | Should -BeTrue
            $script:Graph['settings'] = New-DirectorySetting @{ LockoutDurationInSeconds = '120' }
            Test-MtCheckEidscaPR05 | Should -BeTrue
        }
        It 'fails below the threshold (compared as numbers, not text)' {
            $script:Graph['settings'] = New-DirectorySetting @{ LockoutDurationInSeconds = '30' }
            Test-MtCheckEidscaPR05 | Should -BeFalse
        }
    }

    Context '-le (EIDSCA.PR06)' {
        It 'passes at or below the threshold' {
            $script:Graph['settings'] = New-DirectorySetting @{ LockoutThreshold = '10' }
            Test-MtCheckEidscaPR06 | Should -BeTrue
        }
        It 'fails above the threshold' {
            $script:Graph['settings'] = New-DirectorySetting @{ LockoutThreshold = '11' }
            Test-MtCheckEidscaPR06 | Should -BeFalse
        }
    }

    Context 'skip conditions' {
        It 'EIDSCA.CR04 skips when the admin consent workflow is disabled' {
            $script:Graph['policies/adminConsentRequestPolicy'] = [pscustomobject]@{ isEnabled = $false; requestDurationInDays = 30 }
            Test-MtCheckEidscaCR04 | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' }
        }
        It 'EIDSCA.CR04 compares with -le when the workflow is enabled' {
            $script:Graph['policies/adminConsentRequestPolicy'] = [pscustomobject]@{ isEnabled = $true; requestDurationInDays = 45 }
            Test-MtCheckEidscaCR04 | Should -BeFalse
            $script:Graph['policies/adminConsentRequestPolicy'] = [pscustomobject]@{ isEnabled = $true; requestDurationInDays = 14 }
            Test-MtCheckEidscaCR04 | Should -BeTrue
        }
        It 'EIDSCA.AF05 skips when key restrictions are not enforced, without calling the EIDSCA.AF04 function' {
            $script:EnabledAuthMethods = @('Fido2')
            $script:Graph["policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"] = [pscustomobject]@{
                keyRestrictions = [pscustomobject]@{ isEnforced = $false; aaGuids = @('a') }
            }
            Test-MtCheckEidscaAF05 | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' }
        }
        It 'EIDSCA.AF05 skips when FIDO2 is not enabled' {
            $script:Graph["policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"] = [pscustomobject]@{
                keyRestrictions = [pscustomobject]@{ isEnforced = $true; aaGuids = @('a') }
            }
            Test-MtCheckEidscaAF05 | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' }
        }
        It 'EIDSCA.AF05 evaluates when FIDO2 is enabled and key restrictions are enforced' {
            $script:EnabledAuthMethods = @('Fido2')
            $script:Graph["policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"] = [pscustomobject]@{
                keyRestrictions = [pscustomobject]@{ isEnforced = $true; aaGuids = @('a') }
            }
            Test-MtCheckEidscaAF05 | Should -BeTrue
        }
    }

    Context 'metadata' {
        It 'declares the Entra ID P1 licence instead of a licence skip (EIDSCA.PR05)' {
            $test = Get-MtTest -Id EIDSCA.PR05
            $test.CompatibleLicense | Should -Be 'AAD_PREMIUM'
            $test.Service | Should -Be 'Graph'
            (Get-Content -Path $test.File -Raw) | Should -Not -Match 'EntraIDPlan'
        }
    }
}

BeforeDiscovery {
    $settingChecks = @(
        @{ Check = 'Test-MtCisaPowerPlatformEnvironmentCreation'; Setting = 'disableEnvironmentCreationByNonAdminUsers'; Nested = $false }
        @{ Check = 'Test-MtCisaPowerPlatformTrialEnvironmentCreation'; Setting = 'disableTrialEnvironmentCreationByNonAdminUsers'; Nested = $false }
        @{ Check = 'Test-MtCisaPowerPlatformPowerPagesCreation'; Setting = 'disablePortalsCreationByNonAdminUsers'; Nested = $false }
        @{ Check = 'Test-MtCisaPowerPlatformShareWithEveryoneDisabled'; Setting = 'disableShareWithEveryone'; Nested = $true }
    )
}

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
}

Describe 'CISA Power Platform baseline: tenant setting <Check>' -ForEach $settingChecks {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It 'passes only when the audited setting is true' {
        foreach ($value in $true, $false) {
            Mock -ModuleName Maester Get-MtPowerPlatformTenantSetting {
                if ($Nested) {
                    [pscustomobject]@{ powerPlatform = [pscustomobject]@{ powerApps = [pscustomobject]@{ $Setting = $value } } }
                }
                else {
                    [pscustomobject]@{ $Setting = $value }
                }
            }

            $result = @(InModuleScope Maester -Parameters @{ Check = $Check } {
                    param($Check)
                    & $Check
                })
            $result | Should -HaveCount 1
            $result[0] | Should -Be $value
        }
    }

    It 'throws when the setting is missing' {
        Mock -ModuleName Maester Get-MtPowerPlatformTenantSetting { [pscustomobject]@{ unrelated = $true } }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*was not returned*'
        }
    }
}

Describe 'CISA Power Platform baseline: DLP policy scope' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
        Mock -ModuleName Maester Get-MtPowerPlatformEnvironment {
            [pscustomobject]@{ Name = 'Default-1'; DisplayName = 'Default'; IsDefault = $true; EnvironmentType = 'Default' }
            [pscustomobject]@{ Name = 'Dev'; DisplayName = 'Dev'; IsDefault = $false; EnvironmentType = 'Sandbox' }
        }
    }

    It 'fails the default environment check when no policy exists' {
        Mock -ModuleName Maester Get-MtPowerPlatformDlpPolicy { }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformDefaultEnvironmentDlp | Should -BeFalse
        }
    }

    It 'passes the default environment check when an except policy does not list it' {
        Mock -ModuleName Maester Get-MtPowerPlatformDlpPolicy {
            [pscustomobject]@{ DisplayName = 'P'; Scope = 'ExceptEnvironments'; Environments = @('Dev') }
        }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformDefaultEnvironmentDlp | Should -BeTrue
        }
    }

    It 'fails the non-default check when an environment is only excluded' {
        Mock -ModuleName Maester Get-MtPowerPlatformDlpPolicy {
            [pscustomobject]@{ DisplayName = 'P'; Scope = 'ExceptEnvironments'; Environments = @('Dev') }
        }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformNonDefaultEnvironmentDlp | Should -BeFalse
        }
    }

    It 'passes the non-default check for an all-environments policy' {
        Mock -ModuleName Maester Get-MtPowerPlatformDlpPolicy {
            [pscustomobject]@{ DisplayName = 'P'; Scope = 'AllEnvironments'; Environments = @() }
        }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformNonDefaultEnvironmentDlp | Should -BeTrue
        }
    }
}

Describe 'CISA Power Platform baseline: tenant isolation' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It 'fails when the policy was never configured' {
        Mock -ModuleName Maester Get-MtPowerPlatformTenantIsolation { $null }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformTenantIsolationEnabled | Should -BeFalse
        }
    }

    It 'passes only when isDisabled is false' {
        Mock -ModuleName Maester Get-MtPowerPlatformTenantIsolation {
            [pscustomobject]@{ properties = [pscustomobject]@{ isDisabled = $false; allowedTenants = @() } }
        }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformTenantIsolationEnabled | Should -BeTrue
        }
        Mock -ModuleName Maester Get-MtPowerPlatformTenantIsolation {
            [pscustomobject]@{ properties = [pscustomobject]@{ isDisabled = $true } }
        }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformTenantIsolationEnabled | Should -BeFalse
        }
    }

    It 'requires investigation for the allowlist review' {
        Mock -ModuleName Maester Get-MtPowerPlatformTenantIsolation { $null }
        InModuleScope Maester {
            Test-MtCisaPowerPlatformTenantIsolationAllowlist | Should -BeFalse
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Investigate }
    }
}

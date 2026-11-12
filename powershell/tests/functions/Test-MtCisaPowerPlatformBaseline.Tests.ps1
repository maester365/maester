[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'BeforeDiscovery data is consumed by -ForEach on the Describe block.')]
param()

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

    if (-not (Get-Command Get-AzContext -ErrorAction SilentlyContinue)) {
        function global:Get-AzContext { }
        $script:removeAzContextStub = $true
    }
}

AfterAll {
    if ($script:removeAzContextStub) {
        Remove-Item -Path Function:\Get-AzContext -ErrorAction SilentlyContinue
    }
}

Describe 'Power Platform service layer' {
    It 'treats a policy stored under an environment as scoped to that environment only' {
        InModuleScope Maester {
            $__MtSession.PowerPlatformCache = @{}
        }
        Mock -ModuleName Maester Invoke-MtPowerPlatformRequest {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ name = 'a'; id = '/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/Dev-1/apiPolicies/a'; properties = [pscustomobject]@{ displayName = 'Env' } }
                    [pscustomobject]@{ name = 'b'; id = '/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies/b'; properties = [pscustomobject]@{ displayName = 'Tenant' } }
                )
            }
        }

        $policies = InModuleScope Maester { Get-MtPowerPlatformDlpPolicy }
        $policies[0].Scope | Should -Be 'OnlyEnvironments'
        $policies[0].Environments | Should -Be @('Dev-1')
        $policies[1].Scope | Should -Be 'AllEnvironments'
    }

    It 'rejects a DLP response without a policy collection' {
        InModuleScope Maester {
            $__MtSession.PowerPlatformCache = @{}
        }
        Mock -ModuleName Maester Invoke-MtPowerPlatformRequest { $null }

        $message = InModuleScope Maester {
            try {
                Get-MtPowerPlatformDlpPolicy
            }
            catch {
                $_.Exception.Message
            }
        }
        $message | Should -BeLike '*did not return a policy collection*'
    }

    It 'refuses to call the API when the Azure and Graph tenants differ' {
        Mock -ModuleName Maester Get-AzContext {
            [pscustomobject]@{ Environment = [pscustomobject]@{ Name = 'AzureCloud' }; Tenant = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' } }
        }
        Mock -ModuleName Maester Get-MgContext { [pscustomobject]@{ TenantId = '22222222-2222-2222-2222-222222222222' } }

        $message = InModuleScope Maester {
            try {
                Invoke-MtPowerPlatformRequest -RelativeUri '/x'
            }
            catch {
                $_.Exception.Message
            }
        }
        $message | Should -BeLike '*does not match the Microsoft Graph tenant*'
    }
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

        $message = InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            try {
                & $Check
            }
            catch {
                $_.Exception.Message
            }
        }
        $message | Should -BeLike '*was not returned*'
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

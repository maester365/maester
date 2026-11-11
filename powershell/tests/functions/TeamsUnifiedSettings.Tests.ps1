BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    if (-not ('MaesterTestDeviceCodeResult' -as [type])) {
        $null = Add-Type -TypeDefinition @'
public sealed class MaesterTestDeviceCodeResult
{
    public MaesterTestDeviceCodeResult(string message)
    {
        Message = message;
    }

    public string Message { get; }
}

public static class MaesterTestDeviceCodeCallbackInvoker
{
    public static System.Threading.Tasks.Task Invoke(System.Delegate callback, object deviceCode)
    {
        return System.Threading.Tasks.Task.Run(async () =>
            await (System.Threading.Tasks.Task)callback.DynamicInvoke(deviceCode));
    }
}
'@ -ErrorAction Stop
    }
}

Describe 'Get-MtTeamsUnifiedTenantSettings' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.TeamsCache = @{}
            $__MtSession.TeamsAuthCache = @{}
            $__MtSession.TeamsEnvironmentName = $null
        }
        Mock Get-MgContext -ModuleName Maester {
            [pscustomobject]@{
                TenantId    = '11111111-1111-1111-1111-111111111111'
                Environment = 'Global'
                AuthType    = 'Delegated'
                Account     = 'admin@contoso.com'
            }
        }
        Mock Get-MtTeamsUnifiedSettingsAccessToken -ModuleName Maester {
            'test-token'
        }
        Mock Invoke-RestMethod -ModuleName Maester {
            @([pscustomobject]@{ SettingName = 'DefaultApp'; SettingValue = 'None' })
        }
    }

    It 'Retrieves settings with a delegated token and caches them for the current run' {
        $first = InModuleScope Maester { @(Get-MtTeamsUnifiedTenantSettings) }
        $second = InModuleScope Maester { @(Get-MtTeamsUnifiedTenantSettings) }

        $first | Should -HaveCount 1
        $first[0].SettingName | Should -Be 'DefaultApp'
        $second[0].SettingValue | Should -Be 'None'
        Should -Invoke Get-MtTeamsUnifiedSettingsAccessToken -ModuleName Maester -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://substrate.office.com/AdminAppCatalog/ps/v2/admin/unifiedApp/settings' -and
            $Method -eq 'Get' -and
            $Headers.Authorization -eq 'Bearer test-token'
        }
    }

    It 'Uses legacy policies in US Government environments' {
        Mock Get-MgContext -ModuleName Maester {
            [pscustomobject]@{
                TenantId    = '11111111-1111-1111-1111-111111111111'
                Environment = 'USGov'
                AuthType    = 'Delegated'
            }
        }

        InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Times 0 -Exactly
    }

    It 'Uses legacy policies in US Government DoD environments' {
        Mock Get-MgContext -ModuleName Maester {
            [pscustomobject]@{
                TenantId    = '11111111-1111-1111-1111-111111111111'
                Environment = 'USGovDoD'
                AuthType    = 'Delegated'
            }
        }

        InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Times 0 -Exactly
    }

    It 'Uses legacy policies when Teams is connected to GCC High' {
        InModuleScope Maester {
            $__MtSession.TeamsEnvironmentName = 'TeamsGCCH'
        }

        InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Times 0 -Exactly
    }

    It 'Uses legacy policies for app-only authentication' {
        Mock Get-MgContext -ModuleName Maester {
            [pscustomobject]@{
                TenantId    = '11111111-1111-1111-1111-111111111111'
                Environment = 'Global'
                AuthType    = 'AppOnly'
            }
        }

        InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Times 0 -Exactly
    }

    It 'Throws when the unified settings API returns a malformed setting' {
        Mock Invoke-RestMethod -ModuleName Maester {
            @([pscustomobject]@{ SettingName = 'DefaultApp' })
        }

        { InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } } | Should -Throw '*without SettingName or SettingValue*'
    }

    It 'Surfaces API request failures instead of silently falling back' {
        Mock Invoke-RestMethod -ModuleName Maester { throw 'request failed' }

        { InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } } | Should -Throw '*request failed*'
    }

    It 'Throws when no Graph context is available' {
        Mock Get-MgContext -ModuleName Maester { $null }

        { InModuleScope Maester { Get-MtTeamsUnifiedTenantSettings } } | Should -Throw '*Graph context is required*'
    }

    It 'Captures the device-code message through a managed callback' {
        $messageSource = [System.Threading.Tasks.TaskCompletionSource[string]]::new()
        $deviceCode = [MaesterTestDeviceCodeResult]::new('Use the displayed code to sign in.')
        $callback = InModuleScope Maester -Parameters @{
            DeviceCodeType = $deviceCode.GetType()
            MessageSource  = $messageSource
        } {
            Get-MtTeamsUnifiedSettingsDeviceCodeCallback -DeviceCodeType $DeviceCodeType -MessageSource $MessageSource
        }

        [MaesterTestDeviceCodeCallbackInvoker]::Invoke($callback, $deviceCode).GetAwaiter().GetResult()
        $messageSource.Task.GetAwaiter().GetResult() | Should -Be 'Use the displayed code to sign in.'
    }
}

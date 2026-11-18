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

public sealed class MaesterTestUnifiedTokenClient
{
    public System.Threading.Tasks.Task<object[]> GetAccountsAsync()
    {
        return System.Threading.Tasks.Task.FromResult(new object[0]);
    }

    public MaesterTestUnifiedTokenRequest AcquireTokenInteractive(System.Collections.Generic.IEnumerable<string> scopes)
    {
        return new MaesterTestUnifiedTokenRequest();
    }
}

public sealed class MaesterTestUnifiedTokenRequest
{
    public MaesterTestUnifiedTokenRequest WithUseEmbeddedWebView(bool enabled) { return this; }
    public MaesterTestUnifiedTokenRequest WithLoginHint(string account) { return this; }
    public System.Threading.Tasks.Task<MaesterTestUnifiedTokenResult> ExecuteAsync()
    {
        return System.Threading.Tasks.Task.FromResult(new MaesterTestUnifiedTokenResult());
    }
}

public sealed class MaesterTestUnifiedTokenResult
{
    public string AccessToken { get { return "interactive-test-token"; } }
}
'@ -ErrorAction Stop
    }

    if (-not ('MaesterTestUnifiedDeviceCodeClient' -as [type])) {
        $null = Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public sealed class MaesterTestUnifiedDeviceCodeClient
{
    private readonly TaskCompletionSource<MaesterTestUnifiedDeviceCodeResult> _tokenSource = new TaskCompletionSource<MaesterTestUnifiedDeviceCodeResult>();

    public bool TokenWasReleasedWhilePending { get; private set; }

    public Task<object[]> GetAccountsAsync()
    {
        return Task.FromResult(new object[0]);
    }

    public MaesterTestUnifiedDeviceCodeRequest AcquireTokenWithDeviceCode(IEnumerable<string> scopes, Delegate callback)
    {
        return new MaesterTestUnifiedDeviceCodeRequest(this);
    }

    public Task<MaesterTestUnifiedDeviceCodeResult> GetTokenTask()
    {
        Task.Delay(5000).ContinueWith(_ => _tokenSource.TrySetException(new TimeoutException("The host did not release the device-code token.")));
        return _tokenSource.Task;
    }

    public void ReleaseTokenFromHost()
    {
        TokenWasReleasedWhilePending = !_tokenSource.Task.IsCompleted;
        _tokenSource.TrySetResult(new MaesterTestUnifiedDeviceCodeResult());
    }
}

public sealed class MaesterTestUnifiedDeviceCodeRequest
{
    private readonly MaesterTestUnifiedDeviceCodeClient _client;

    public MaesterTestUnifiedDeviceCodeRequest(MaesterTestUnifiedDeviceCodeClient client)
    {
        _client = client;
    }

    public Task<MaesterTestUnifiedDeviceCodeResult> ExecuteAsync()
    {
        return _client.GetTokenTask();
    }
}

public sealed class MaesterTestUnifiedDeviceCodeResult
{
    public string AccessToken { get { return "device-code-test-token"; } }
}
'@ -ErrorAction Stop
    }

}

Describe 'Get-MtTeamsUnifiedSettingsAccessToken' {
    BeforeAll {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    }

    It 'Passes scopes to the MSAL interactive overload and returns its access token' {
        InModuleScope Maester {
            $tenantId = '11111111-1111-1111-1111-111111111111'
            $__MtSession.TeamsUseDeviceCode = $false
            $__MtSession.TeamsAuthCache = @{
                Clients = @{ "$tenantId|Global" = [MaesterTestUnifiedTokenClient]::new() }
            }
            $context = [pscustomobject]@{
                TenantId = $tenantId
                Environment = 'Global'
                Account = 'admin@contoso.com'
            }

            Get-MtTeamsUnifiedSettingsAccessToken -Context $context |
                Should -Be 'interactive-test-token'
        }
    }

    It 'Writes device-code instructions directly to the host before waiting for a token' {
        $tenantId = '11111111-1111-1111-1111-111111111111'
        $context = [pscustomobject]@{
            TenantId = $tenantId
            Environment = 'Global'
            Account = $null
        }
        $client = [MaesterTestUnifiedDeviceCodeClient]::new()

        $output = @(
            InModuleScope Maester -Parameters @{ Context = $context; Client = $client } {
                $__MtSession.TeamsUseDeviceCode = $true
                $__MtSession.TeamsAuthCache = @{
                    Clients = @{ "$($Context.TenantId)|$($Context.Environment)" = $Client }
                }
                $script:deviceCodeTestClient = $Client
                Mock Get-MtTeamsUnifiedSettingsDeviceCodeCallback {
                    $null = $MessageSource.TrySetResult('Use the displayed code to sign in.')
                }
                Mock Write-MtHostLine {
                    $null = $script:deviceCodeTestClient.ReleaseTokenFromHost()
                }

                try {
                    Get-MtTeamsUnifiedSettingsAccessToken -Context $Context 6>&1
                } finally {
                    $script:deviceCodeTestClient = $null
                }
            }
        )

        @($output | Where-Object { $_ -is [System.Management.Automation.InformationRecord] }) |
            Should -BeNullOrEmpty
        $output | Should -Contain 'device-code-test-token'
        $client.TokenWasReleasedWhilePending | Should -BeTrue
        Should -Invoke Write-MtHostLine -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Text -eq 'Use the displayed code to sign in.'
        }
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

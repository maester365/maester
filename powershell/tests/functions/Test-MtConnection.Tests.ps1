BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Bypass Pester's slow command-resolution path when MS service modules are not loaded
    # in the test environment. Track which stubs we created so AfterAll cleans up only
    # those — never touch real cmdlets that were already present.
    $script:createdStubs = @()
    foreach ($cmd in 'Get-AzContext','Invoke-AzRestMethod','Get-MgContext','Get-CsTenant','Get-PnPConnection') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdStubs += $cmd
        }
    }
}

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtConnection — Active Directory service' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
        }
    }

    It 'Offers ActiveDirectory as a -Service option' {
        $serviceParameter = (Get-Command Test-MtConnection).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'ActiveDirectory'
    }

    It 'Documents that Active Directory requires an explicit connection and is not included in All' {
        $help = Get-Help Test-MtConnection -Detailed | Out-String
        $help | Should -Match 'Active Directory and GitHub require an explicit connection'
        $help | Should -Match 'Active Directory is not included in -Service All'
    }

    It 'Returns false before Connect-Maester validates Active Directory' {
        Test-MtConnection -Service ActiveDirectory | Should -BeFalse
    }

    It 'Returns true after Connect-Maester validates Active Directory' {
        InModuleScope Maester {
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected            = $true
                DomainController     = 'dc01.contoso.com'
                DefaultNamingContext = 'DC=contoso,DC=com'
            }
        }

        Test-MtConnection -Service ActiveDirectory | Should -BeTrue
    }

    It 'Returns Active Directory details only when explicitly requested' {
        InModuleScope Maester {
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected        = $true
                DomainController = 'dc01.contoso.com'
            }
        }

        $result = Test-MtConnection -Service ActiveDirectory -Details

        $result.ActiveDirectory.Connected | Should -BeTrue
        $result.ActiveDirectory.DomainController | Should -Be 'dc01.contoso.com'
        $result.AllConnected | Should -BeTrue
    }

    It 'Formats Active Directory connection details' {
        InModuleScope Maester {
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected                  = $true
                DomainController           = 'dc01.contoso.com'
                DefaultNamingContext       = 'DC=contoso,DC=com'
                ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
            }
        }

        $rendered = Test-MtConnection -Service ActiveDirectory -Details | Out-String

        $rendered | Should -Match 'Active Directory'
        $rendered | Should -Match 'dc01.contoso.com'
        $rendered | Should -Match 'DC=contoso,DC=com'
    }
}

Describe 'Test-MtConnection — GitHub service' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection      = $null
            $__MtSession.ADConnection          = $null
            $__MtSession.AzureDevOpsConnectionCache = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection      = $null
            $__MtSession.ADConnection          = $null
            $__MtSession.AzureDevOpsConnectionCache = $null
        }
    }

    Context 'Help' {
        It 'Documents the -Service All GitHub explicit connection behavior' {
            $help = Get-Help Test-MtConnection -Detailed | Out-String
            $help | Should -Match 'not included in -Service All'
            $help | Should -Not -Match 'NotCalled sentinel'
            $help | Should -Match 'must be checked explicitly'
        }
    }

    Context 'When Connect-MtGitHub has never been called' {
        It 'Returns $false for -Service GitHub' {
            InModuleScope Maester {
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }

        It 'Records that Connect-MtGitHub has not been called' {
            InModuleScope Maester {
                Test-MtConnection -Service GitHub | Out-Null
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'NotCalled'
            }
        }
    }

    Context 'When GitHub is explicitly disconnected' {
        It 'Returns $false when Connected is $false' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }

        It 'Returns $false when membership is pending (FailureReason = OrgMembershipPending)' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipPending' }
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }
    }

    Context 'When GitHub is connected' {
        It 'Returns $true' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                Test-MtConnection -Service GitHub | Should -BeTrue
            }
        }

        It 'Returns an object with GitHub populated and AllConnected $true when using -Details' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $result = Test-MtConnection -Service GitHub -Details
                $result.GitHub | Should -Not -BeNullOrEmpty
                $result.GitHub.Connected | Should -BeTrue
                $result.AllConnected | Should -BeTrue
            }
        }
    }

    Context 'When GitHub is not connected' {
        It 'Returns an object with GitHub $null and AllConnected $false when using -Details' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NoToken' }
                $result = Test-MtConnection -Service GitHub -Details
                $result.GitHub | Should -BeNullOrEmpty
                $result.AllConnected | Should -BeFalse
            }
        }
    }

    Context '-Service GitHub -Details with GitHub connected' {
        It 'Populates the GitHub property and returns AllConnected $true' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
            }
            $result = Test-MtConnection -Service GitHub -Details
            $result.GitHub | Should -Not -BeNullOrEmpty
            $result.GitHub.Connected | Should -BeTrue
            $result.AllConnected | Should -BeTrue
        }
    }

    Context '-Service All - GitHub is not included' {
        It 'Returns AllConnected $true when all included services are connected and GitHub session is absent' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = $null
                $__MtSession.AzureDevOpsConnectionCache = [PSCustomObject]@{ Organization = 'ado-org' }
            }
            Mock Get-AzContext { [PSCustomObject]@{ Account = 'test@contoso.com' } } -ModuleName Maester
            Mock Invoke-AzRestMethod { [PSCustomObject]@{} } -ModuleName Maester
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-MtExo {
                @(
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $false }
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $true }
                )
            } -ModuleName Maester
            Mock Get-CsTenant { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-PnPConnection { [PSCustomObject]@{ Url = 'https://contoso.sharepoint.com' } } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.AllConnected | Should -BeTrue
            $result.GitHub | Should -BeNullOrEmpty
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
            }
        }
    }

    Context '-Service All - GitHub NotCalled sentinel is ignored' {
        It 'does not set the GitHub details property' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = [PSCustomObject]@{ Connected = $false; FailureReason = 'NotCalled' }
                $__MtSession.AzureDevOpsConnectionCache = 'NotConnected'
            }
            Mock Get-AzContext { [PSCustomObject]@{ Account = 'test@contoso.com' } } -ModuleName Maester
            Mock Invoke-AzRestMethod { [PSCustomObject]@{} } -ModuleName Maester
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-MtExo {
                @(
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $false }
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $true }
                )
            } -ModuleName Maester
            Mock Get-CsTenant { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.AllConnected | Should -BeFalse
            $result.GitHub | Should -BeNullOrEmpty
        }
    }

    Context '-Service GitHub -Details formatted output' {
        It 'Renders safe GitHub metadata and excludes auth/token values' {
            $fakeToken = 'ghp_FAKE_TOKEN_VALUE_DO_NOT_USE'
            InModuleScope Maester -ArgumentList $fakeToken {
                param($FakeToken)
                $__MtSession.GitHubConnection = [PSCustomObject]@{
                    Connected                        = $true
                    Organization                     = 'myorg'
                    TokenLogin                       = 'octocat'
                    ApiBaseUri                       = 'https://api.github.com'
                    ApiVersion                       = '2022-11-28'
                    Role                             = 'admin'
                    RoleState                        = 'active'
                    AdministrationPermissionVerified = $true
                }
                $__MtSession.GitHubAuthHeader = @{
                    Authorization = "Bearer $FakeToken"
                }
            }
            $rendered = Test-MtConnection -Service GitHub -Details | Out-String
            $rendered | Should -Match 'GitHub'
            $rendered | Should -Match 'myorg'
            $rendered | Should -Match 'octocat'
            $rendered | Should -Not -Match 'Bearer'
            $rendered | Should -Not -Match 'Authorization'
            $rendered | Should -Not -Match ([regex]::Escape($fakeToken))
        }
    }

    Context '-Service All — GitHub connected session is ignored' {
        It 'Does not populate the GitHub or Active Directory properties' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.ADConnection          = [PSCustomObject]@{ Connected = $true; DomainController = 'dc01.contoso.com' }
                $__MtSession.AzureDevOpsConnectionCache = 'NotConnected'
            }
            Mock Get-AzContext { [PSCustomObject]@{ Account = 'test@contoso.com' } } -ModuleName Maester
            Mock Invoke-AzRestMethod { [PSCustomObject]@{} } -ModuleName Maester
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-MtExo {
                @(
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $false }
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $true }
                )
            } -ModuleName Maester
            Mock Get-CsTenant { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.GitHub | Should -BeNullOrEmpty
            $result.ActiveDirectory | Should -BeNullOrEmpty
        }
    }
}

Describe 'Test-MtConnection — Microsoft Graph scopes' {
    It 'Returns included and missing Graph scopes when Details is requested' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                TenantId   = 'tenant-id'
                Environment = 'Global'
                Account    = 'admin@contoso.com'
                AuthType   = 'Delegated'
                Scopes     = @(
                    'Directory.Read.All'
                    'Policy.Read.ConditionalAccess'
                )
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            @(
                'Directory.Read.All'
                'Policy.Read.ConditionalAccess'
                'Reports.Read.All'
            )
        } -ModuleName Maester

        $Result = Test-MtConnection -Service Graph -Details

        @($Result.Graph.Scopes).Count | Should -Be 2
        $Result.Graph.Scopes | Should -Contain 'Directory.Read.All'
        $Result.Graph.Scopes | Should -Contain 'Policy.Read.ConditionalAccess'

        @($Result.Graph.MissingScopes).Count | Should -Be 1
        $Result.Graph.MissingScopes | Should -Contain 'Reports.Read.All'

        $Result.AllConnected | Should -BeTrue
    }

    It 'Treats a ReadWrite scope as satisfying the corresponding Read scope' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                TenantId   = 'tenant-id'
                Environment = 'Global'
                Account    = 'admin@contoso.com'
                AuthType   = 'Delegated'
                Scopes     = @(
                    'Directory.Read.All'
                    'Policy.ReadWrite.ConditionalAccess'
                )
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            @(
                'Directory.Read.All'
                'Policy.Read.ConditionalAccess'
            )
        } -ModuleName Maester

        $Result = Test-MtConnection -Service Graph -Details

        $Result.Graph.Scopes |
            Should -Contain 'Policy.ReadWrite.ConditionalAccess'

        $Result.Graph.MissingScopes |
            Should -Not -Contain 'Policy.Read.ConditionalAccess'
    }

    It 'Returns disconnected state when no Graph context exists' {
        Mock Get-MgContext { $null } -ModuleName Maester

        $Result = Test-MtConnection -Service Graph -Details

        $Result.Graph | Should -BeNullOrEmpty
        $Result.AllConnected | Should -BeFalse
    }

    It 'Formats included and missing Graph scopes' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                TenantId    = 'tenant-id'
                Environment = 'Global'
                Account     = 'admin@contoso.com'
                AuthType    = 'Delegated'
                Scopes      = @('Directory.Read.All')
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            @(
                'Directory.Read.All'
                'Reports.Read.All'
            )
        } -ModuleName Maester

        $Rendered = Test-MtConnection -Service Graph -Details | Out-String

        $Rendered | Should -Match 'Included scopes:\s+1'
        $Rendered | Should -Match 'Directory\.Read\.All'
        $Rendered | Should -Match 'Missing scopes:\s+1'
        $Rendered | Should -Match 'Reports\.Read\.All'
    }

    It 'Keeps the Graph connection details when scope evaluation fails' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                TenantId    = 'tenant-id'
                Environment = 'Global'
                Account     = 'admin@contoso.com'
                AuthType    = 'Delegated'
                Scopes      = @('Directory.Read.All')
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            throw 'Unable to retrieve required scopes'
        } -ModuleName Maester

        $Result = Test-MtConnection -Service Graph -Details

        $Result.Graph | Should -Not -BeNullOrEmpty
        $Result.Graph.TenantId | Should -Be 'tenant-id'
        $Result.AllConnected | Should -BeTrue
    }
}

Describe 'Test-MtConnection AzureDevOps cache' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = $null
            $__MtSession.Remove('AzureDevOpsConnection')
        }
    }

    AfterEach {
        InModuleScope Maester {
            Remove-Item -Path function:Get-ADOPSConnection -ErrorAction SilentlyContinue
            $__MtSession.AzureDevOpsConnectionCache = $null
            $__MtSession.Remove('AzureDevOpsConnection')
        }
    }

    It 'caches a successful Azure DevOps probe under a cache-specific key' {
        $result = InModuleScope Maester {
            New-Item -Path function:Get-ADOPSConnection -Value { @{ Organization = 'ado-org' } } -Force | Out-Null
            Test-MtConnection -Service AzureDevOps -Details
        }

        $result.AllConnected | Should -BeTrue
        $result.AzureDevOps['Organization'] | Should -Be 'ado-org'
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache['Organization'] | Should -Be 'ado-org'
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }

    It 'caches a failed Azure DevOps probe as NotConnected' {
        $result = InModuleScope Maester {
            New-Item -Path function:Get-ADOPSConnection -Value { $null } -Force | Out-Null
            Test-MtConnection -Service AzureDevOps -Details
        }

        $result.AllConnected | Should -BeFalse
        $result.AzureDevOps | Should -BeNullOrEmpty
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache | Should -Be 'NotConnected'
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }

    It 'uses the cached Azure DevOps probe result without re-querying the external command' {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'cached-org' }
        }
        $result = InModuleScope Maester {
            New-Item -Path function:Get-ADOPSConnection -Value { throw 'Get-ADOPSConnection should not be called when cache exists.' } -Force | Out-Null
            Test-MtConnection -Service AzureDevOps -Details
        }

        $result.AllConnected | Should -BeTrue
        $result.AzureDevOps['Organization'] | Should -Be 'cached-org'
    }

    It 'clears the Azure DevOps probe cache during module-variable reset' {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'cached-org' }

            Clear-ModuleVariable

            $__MtSession.AzureDevOpsConnectionCache | Should -BeNullOrEmpty
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }
}

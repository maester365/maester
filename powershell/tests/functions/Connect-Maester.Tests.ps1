BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Keep -Service All tests isolated from optional service modules that may not be installed.
    $script:createdStubs = @()
    foreach ($cmd in 'Get-AzContext','Connect-AzAccount','Connect-ExchangeOnline','Connect-IPPSSession','Get-ConnectionInformation','Connect-MgGraph','Connect-MicrosoftTeams') {
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

Describe 'Connect-Maester' {
    BeforeAll {
        # Capture the summary rows instead of printing the table.
        Mock Write-MtConnectionSummary -ModuleName Maester { $script:summaryRows = $Connection }

        function Get-SummaryRow {
            param([string] $ServiceName)
            $script:summaryRows | Where-Object Service -eq $ServiceName
        }
    }

    BeforeEach {
        $script:summaryRows = $null
    }

    It 'Offers GitHub as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'GitHub'
    }

    It 'Offers ActiveDirectory as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'ActiveDirectory'
    }

    It 'Offers GitHubOrganization as a parameter' {
        (Get-Command Connect-Maester).Parameters.Keys | Should -Contain 'GitHubOrganization'
    }

    It 'Offers ClientTimeout as a double parameter' {
        $clientTimeoutParameter = (Get-Command Connect-Maester).Parameters['ClientTimeout']

        $clientTimeoutParameter | Should -Not -BeNullOrEmpty
        $clientTimeoutParameter.ParameterType | Should -Be ([double])
    }

    It 'Passes IncludePreview to Get-MtGraphScope' {
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Get-MtGraphScope -ModuleName Maester { @('AgentIdentity.Read.All') }

        Connect-Maester -IncludePreview

        Should -Invoke Get-MtGraphScope -ModuleName Maester -Times 1 -Exactly `
            -ParameterFilter { $IncludePreview }
    }

    It 'Passes an explicit ClientTimeout to Connect-MgGraph' {
        Mock Connect-MgGraph -ModuleName Maester {}

        Connect-Maester -ClientTimeout 900

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $ClientTimeout -eq 900 }
    }

    It 'Does not pass ClientTimeout to Connect-MgGraph when omitted' {
        Mock Connect-MgGraph -ModuleName Maester {}

        Connect-Maester

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('ClientTimeout') }
    }

    It 'Shows consent guidance when Connect-MgGraph fails with an approval error' {
        # CI runners set $ErrorActionPreference = 'Stop'. Pin it here (the mock body reads this scope)
        # and on Connect-Maester so the mocked error stays non-terminating.
        $ErrorActionPreference = 'Continue'
        Mock Connect-MgGraph -ModuleName Maester {
            Write-Error 'InteractiveBrowserCredential authentication failed: User canceled authentication.'
        }
        Mock Write-MtGraphConsentHelp -ModuleName Maester { $true }

        Connect-Maester -TenantId 'contoso.onmicrosoft.com' -Environment USGov -ErrorAction Continue 2>$null

        Should -Invoke Write-MtGraphConsentHelp -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $TenantId -eq 'contoso.onmicrosoft.com' -and $Environment -eq 'USGov'
        }
    }

    It 'Does not show consent guidance when Connect-MgGraph succeeds' {
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Write-MtGraphConsentHelp -ModuleName Maester { $true }

        Connect-Maester

        Should -Invoke Write-MtGraphConsentHelp -ModuleName Maester -Times 0 -Exactly
    }

    It 'Does not connect to Graph when ClientTimeout is used with a non-Graph service' {
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Connect-MtGitHub -ModuleName Maester {}

        Connect-Maester -Service GitHub -ClientTimeout 900

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 0 -Exactly
    }

    It 'Calls Connect-MtGitHub when -Service GitHub is specified' {
        Mock Connect-MtGitHub -ModuleName Maester {}

        Connect-Maester -Service GitHub

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly
    }

    It 'Passes -GitHubOrganization to Connect-MtGitHub' {
        Mock Connect-MtGitHub -ModuleName Maester -ParameterFilter { $Organization -eq 'myorg' } {}

        Connect-Maester -Service GitHub -GitHubOrganization 'myorg'

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'myorg' }
    }

    It 'Validates Active Directory through the protocol-aware target selector' {
        Mock Connect-MtAdTarget -ModuleName Maester {
            InModuleScope Maester {
                $__MtSession.ADConnection = [PSCustomObject]@{
                    Connected          = $true
                    ProtocolValidated  = $true
                    ResolvedServer     = 'dc01.contoso.com'
                    ResolvedDomain     = 'contoso.com'
                    ResolvedForest     = 'contoso.com'
                    AuthenticationMode = 'Negotiate'
                    TlsMode            = 'Ldaps'
                }
            }
        }

        $verboseOutput = Connect-Maester -Service ActiveDirectory -Verbose 4>&1

        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $AuthMode -eq 'Negotiate' -and $TlsMode -eq 'Auto'
        }
        $verboseOutput -join "`n" | Should -Match "resolved target 'dc01.contoso.com'.*auth 'Negotiate'.*TLS 'Ldaps'"
        (Get-SummaryRow ActiveDirectory).Status | Should -Be 'Connected'
        (Get-SummaryRow ActiveDirectory).Details | Should -Be 'dc01.contoso.com (Ldaps)'
    }

    It 'Forwards Active Directory target, credential, authentication, and TLS options' {
        $credential = [PSCredential]::new('CONTOSO\Maester', ([System.Security.SecureString]::new()))
        Mock Connect-MtAdTarget -ModuleName Maester {
            InModuleScope Maester {
                $__MtSession.ADConnection = [PSCustomObject]@{
                    Connected          = $true
                    ProtocolValidated  = $true
                    ResolvedServer     = 'dc02.contoso.com'
                    ResolvedDomain     = 'contoso.com'
                    ResolvedForest     = 'contoso.com'
                    AuthenticationMode = 'Basic'
                    TlsMode            = 'StartTls'
                }
            }
        }

        Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc02.contoso.com' -ActiveDirectoryDomain 'contoso.com' -ActiveDirectoryForest 'contoso.com' -ActiveDirectoryCredential $credential -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode StartTls

        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $ActiveDirectoryServer -eq 'dc02.contoso.com' -and
            $ActiveDirectoryDomain -eq 'contoso.com' -and
            $ActiveDirectoryForest -eq 'contoso.com' -and
            $ActiveDirectoryCredential.UserName -eq 'CONTOSO\Maester' -and
            $AuthMode -eq 'Basic' -and
            $TlsMode -eq 'StartTls'
        }
    }

    It 'Does not call opt-in services when -Service All is specified' {
        Mock Get-AzContext -ModuleName Maester { [PSCustomObject]@{ Account = 'test@contoso.com' } }
        Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { $null }
        Mock Connect-ExchangeOnline -ModuleName Maester {}
        Mock Connect-IPPSSession -ModuleName Maester {}
        Mock Get-ConnectionInformation -ModuleName Maester { @() }
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Connect-MicrosoftTeams -ModuleName Maester {}
        Mock Connect-MtGitHub -ModuleName Maester { throw 'Connect-MtGitHub should not be called for -Service All.' }
        Mock Connect-MtAdTarget -ModuleName Maester { throw 'Connect-MtAdTarget should not be called for -Service All.' }

        Connect-Maester -Service All 3>$null 6>$null

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 0 -Exactly
    }

    Context 'Connection summary' {
        BeforeEach {
            Mock Get-AzContext -ModuleName Maester { [PSCustomObject]@{ Account = [PSCustomObject]@{ Id = 'admin@contoso.com' } } }
            Mock Get-MtMaesterConfigGlobalSetting -ModuleName Maester { $null }
            Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { $null }
            Mock Connect-ExchangeOnline -ModuleName Maester {}
            Mock Connect-IPPSSession -ModuleName Maester {}
            Mock Get-ConnectionInformation -ModuleName Maester {
                [PSCustomObject]@{ IsEopSession = $false; State = 'Connected'; UserPrincipalName = 'admin@contoso.com' }
            }
            Mock Connect-MgGraph -ModuleName Maester {}
            Mock Get-MgContext -ModuleName Maester { [PSCustomObject]@{ Account = 'admin@contoso.com'; TenantId = '00000000-0000-0000-0000-000000000000' } }
            Mock Connect-MicrosoftTeams -ModuleName Maester { [PSCustomObject]@{ Account = 'admin@contoso.com' } }
        }

        It 'Reports every service for -Service All without printing anything else' {
            $otherOutput = Connect-Maester -Service All 3>&1 6>&1

            $otherOutput | Should -BeNullOrEmpty
            (Get-SummaryRow Graph).Status | Should -Be 'Connected'
            (Get-SummaryRow Graph).Details | Should -Be 'admin@contoso.com'
            (Get-SummaryRow Azure).Details | Should -Be 'admin@contoso.com (existing session)'
            (Get-SummaryRow ExchangeOnline).Details | Should -Be 'admin@contoso.com'
            (Get-SummaryRow SecurityCompliance).Status | Should -Be 'Connected'
            (Get-SummaryRow Teams).Details | Should -Be 'admin@contoso.com'
            (Get-SummaryRow Dataverse).Status | Should -Be 'Skipped'
            (Get-SummaryRow Dataverse).Details | Should -Match 'DataverseEnvironmentUrl'
            (Get-SummaryRow SharePointOnline).Status | Should -Be 'Skipped'
            (Get-SummaryRow SharePointOnline).Details | Should -Be '-SharePointClientId was not provided'
            $script:summaryRows.Service | Should -Not -Contain 'GitHub'
            $script:summaryRows.Service | Should -Not -Contain 'ActiveDirectory'
        }

        It 'Reports a module that is not installed and keeps connecting the other services' {
            Mock Connect-ExchangeOnline -ModuleName Maester { throw [System.Management.Automation.CommandNotFoundException]::new('Connect-ExchangeOnline') }
            Mock Connect-IPPSSession -ModuleName Maester { throw [System.Management.Automation.CommandNotFoundException]::new('Connect-IPPSSession') }

            Connect-Maester -Service ExchangeOnline, SecurityCompliance, Graph

            (Get-SummaryRow ExchangeOnline).Status | Should -Be 'Not installed'
            (Get-SummaryRow ExchangeOnline).Details | Should -Be 'Install-Module ExchangeOnlineManagement -Scope CurrentUser'
            (Get-SummaryRow SecurityCompliance).Status | Should -Be 'Not installed'
            (Get-SummaryRow Graph).Status | Should -Be 'Connected'
            Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly
        }

        It 'Reports a failed sign-in as an error and keeps connecting the other services' {
            $ErrorActionPreference = 'Continue'
            Mock Connect-ExchangeOnline -ModuleName Maester { throw 'User canceled authentication.' }

            Connect-Maester -Service ExchangeOnline, Teams -ErrorAction SilentlyContinue -ErrorVariable connectErrors

            (Get-SummaryRow ExchangeOnline).Status | Should -Be 'Failed'
            (Get-SummaryRow ExchangeOnline).Details | Should -Be 'User canceled authentication.'
            (Get-SummaryRow Teams).Status | Should -Be 'Connected'
            $connectErrors.Exception.Message | Should -Contain 'Failed to connect to Exchange Online: User canceled authentication.'
        }

        It 'Reports Security & Compliance connected through the Exchange Online UPN fallback' {
            $script:ippsCalls = 0
            Mock Connect-IPPSSession -ModuleName Maester {
                $script:ippsCalls++
                if ($script:ippsCalls -eq 1) { throw 'Operation did not start in the allotted time.' }
            }
            Mock Get-MtExo -ModuleName Maester { [PSCustomObject]@{ UserPrincipalName = 'admin@contoso.com' } }

            Connect-Maester -Service ExchangeOnline, SecurityCompliance 6>&1 | Should -BeNullOrEmpty

            (Get-SummaryRow SecurityCompliance).Status | Should -Be 'Connected'
            (Get-SummaryRow SecurityCompliance).Details | Should -Be 'admin@contoso.com (UPN from Exchange Online)'
            Should -Invoke Connect-IPPSSession -ModuleName Maester -Times 2 -Exactly
        }

        It 'Reports a Microsoft Graph sign-in error as failed' {
            $ErrorActionPreference = 'Continue'
            Mock Connect-MgGraph -ModuleName Maester { Write-Error 'AADSTS50076: Multi-factor authentication is required.' }
            Mock Write-MtGraphConsentHelp -ModuleName Maester { $false }

            Connect-Maester -ErrorAction Continue 2>$null

            (Get-SummaryRow Graph).Status | Should -Be 'Failed'
            (Get-SummaryRow Graph).Details | Should -Match 'AADSTS50076'
        }

        It 'Skips Dataverse when Azure does not connect' {
            Mock Get-AzContext -ModuleName Maester { $null }
            Mock Connect-AzAccount -ModuleName Maester { throw 'User canceled authentication.' }

            Connect-Maester -Service Dataverse -ErrorAction SilentlyContinue

            (Get-SummaryRow Azure).Status | Should -Be 'Failed'
            (Get-SummaryRow Dataverse).Status | Should -Be 'Skipped'
            (Get-SummaryRow Dataverse).Details | Should -Be 'Needs a working Azure connection'
            Should -Invoke Get-MtDataverseEnvironmentUrl -ModuleName Maester -Times 0 -Exactly
        }

        It 'Reports the GitHub failure reason' {
            Mock Connect-MtGitHub -ModuleName Maester {
                InModuleScope Maester {
                    $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NoToken' }
                }
            }

            Connect-Maester -Service GitHub

            (Get-SummaryRow GitHub).Status | Should -Be 'Failed'
            (Get-SummaryRow GitHub).Details | Should -Be 'NoToken'
        }
    }
}

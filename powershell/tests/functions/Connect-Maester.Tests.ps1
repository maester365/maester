BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Keep -Service All tests isolated from optional service modules that may not be installed.
    $script:createdStubs = @()
    # Mocks with a -ParameterFilter only see parameters the command declares, so give those stubs the parameters the tests filter on.
    $stubBodies = @{
        'Connect-IPPSSession' = {
            [CmdletBinding()]
            param([string]$ConnectionUri, [string]$AzureADAuthorizationEndpointUri, [string]$UserPrincipalName, [switch]$BypassMailboxAnchoring, [switch]$ShowBanner)
            $null = $PSBoundParameters
        }
    }
    foreach ($cmd in 'Get-AzContext','Connect-AzAccount','Get-AzAccessToken','Connect-ExchangeOnline','Connect-IPPSSession','Get-ConnectionInformation','Connect-MgGraph','Connect-MicrosoftTeams') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $stubBody = if ($stubBodies.ContainsKey($cmd)) { $stubBodies[$cmd] } else { { } }
            New-Item -Path "function:global:$cmd" -Value $stubBody | Out-Null
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
    BeforeEach {
        # Keep the test output free of the connection summary table.
        Mock Write-MtConnectionSummary -ModuleName Maester {}
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
}

Describe 'Connect-Maester connection summary' {
    BeforeEach {
        # Capture the rows Connect-Maester hands to the summary table instead of printing them.
        $script:connectionSummaryRows = $null
        Mock Write-MtConnectionSummary -ModuleName Maester { $script:connectionSummaryRows = @($Summary) }

        Mock Get-AzContext -ModuleName Maester { [pscustomobject]@{ Account = [pscustomobject]@{ Id = 'admin@contoso.com' } } }
        Mock Get-MtSetting -ModuleName Maester { $null } -ParameterFilter { $Name -eq 'DataverseEnvironmentUrl' }
        Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { $null }
        Mock Connect-ExchangeOnline -ModuleName Maester {}
        Mock Get-ConnectionInformation -ModuleName Maester {
            [pscustomobject]@{ IsEopSession = $false; State = 'Connected'; UserPrincipalName = 'admin@contoso.com'; ModuleName = 'tmpEXO' }
            [pscustomobject]@{ IsEopSession = $true; State = 'Connected'; UserPrincipalName = 'compliance@contoso.com'; ModuleName = 'tmpEOP' }
        }
        Mock Connect-IPPSSession -ModuleName Maester {}
        # The Get-AdminAuditLogConfig repair re-imports the temporary EXO module after Connect-IPPSSession.
        Mock Import-Module -ModuleName Maester {} -ParameterFilter { $Function -eq 'Get-AdminAuditLogConfig' }
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Get-MgContext -ModuleName Maester { [pscustomobject]@{ Account = 'admin@contoso.com'; TenantId = '00000000-0000-0000-0000-000000000001' } }
        Mock Connect-MicrosoftTeams -ModuleName Maester { [pscustomobject]@{ Account = [pscustomobject]@{ Id = 'admin@contoso.com' } } }
    }

    It 'Reports every service tried by -Service All without extra warnings or host messages (#2302)' {
        $otherOutput = Connect-Maester -Service All -WarningVariable connectWarnings 6>&1 3>$null

        $connectWarnings | Should -BeNullOrEmpty
        $otherOutput | Should -BeNullOrEmpty

        $rows = $script:connectionSummaryRows
        ($rows | ForEach-Object { '{0}={1}' -f $_.Service, $_.Status }) | Should -Be @(
            'Azure=Connected'
            'Dataverse=Skipped'
            'Exchange Online=Connected'
            'Security & Compliance=Connected'
            'Microsoft Graph=Connected'
            'Microsoft Teams=Connected'
            'SharePoint Online=Skipped'
        )
        ($rows | Where-Object Service -eq 'Dataverse').Details | Should -Be 'No environment found, set DataverseEnvironmentUrl in maester-config.json'
        ($rows | Where-Object Service -eq 'SharePoint Online').Details | Should -Be '-SharePointClientId was not provided'
        ($rows | Where-Object Service -eq 'Microsoft Graph').Details | Should -Be 'admin@contoso.com'
        ($rows | Where-Object Service -eq 'Exchange Online').Details | Should -Be 'admin@contoso.com'
        ($rows | Where-Object Service -eq 'Security & Compliance').Details | Should -Be 'compliance@contoso.com'
    }

    It 'Records an Exchange Online failure and still connects the remaining services' {
        Mock Connect-ExchangeOnline -ModuleName Maester { throw [System.PlatformNotSupportedException]::new('macOS 27.0.1') }

        Connect-Maester -Service ExchangeOnline, Graph, Teams 6>$null

        $exchange = $script:connectionSummaryRows | Where-Object Service -eq 'Exchange Online'
        $exchange.Status | Should -Be 'Failed'
        $exchange.Details | Should -Be 'macOS 27.0.1'
        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly
        Should -Invoke Connect-MicrosoftTeams -ModuleName Maester -Times 1 -Exactly
    }

    It 'Shows only the first line of a Teams sign-in error' {
        Mock Connect-MicrosoftTeams -ModuleName Maester {
            throw [System.DllNotFoundException]::new("Unable to load shared library 'kernel32.dll' or one of its dependencies.`ndlopen(kernel32.dll.dylib, 0x0001): tried: ...")
        }

        Connect-Maester -Service Teams 6>$null

        $teams = $script:connectionSummaryRows | Where-Object Service -eq 'Microsoft Teams'
        $teams.Status | Should -Be 'Failed'
        $teams.Details | Should -Be "Unable to load shared library 'kernel32.dll' or one of its dependencies."
    }

    It 'Reports a missing module with its install command' {
        Mock Connect-MicrosoftTeams -ModuleName Maester { throw [System.Management.Automation.CommandNotFoundException]::new('Connect-MicrosoftTeams') }

        Connect-Maester -Service Teams 6>$null

        $teams = $script:connectionSummaryRows | Where-Object Service -eq 'Microsoft Teams'
        $teams.Status | Should -Be 'Not installed'
        $teams.Details | Should -Be 'Run: Install-Module MicrosoftTeams -Scope CurrentUser'
    }

    It 'Notes the Exchange Online UPN when Security & Compliance connects on the retry' {
        Mock Connect-IPPSSession -ModuleName Maester { throw 'Operation did not start in the allotted time.' } -ParameterFilter { -not $UserPrincipalName }
        Mock Connect-IPPSSession -ModuleName Maester {} -ParameterFilter { $UserPrincipalName -eq 'admin@contoso.com' }
        Mock Get-MtExo -ModuleName Maester { [pscustomobject]@{ UserPrincipalName = 'admin@contoso.com' } } -ParameterFilter { $Request -eq 'ConnectionInformation' }

        Connect-Maester -Service ExchangeOnline, SecurityCompliance 6>$null

        $scc = $script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance'
        $scc.Status | Should -Be 'Connected'
        $scc.Details | Should -Be 'Using UPN admin@contoso.com from Exchange Online'
    }

    It 'Separates a failed Dataverse discovery from a tenant without environments' {
        Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { throw 'Could not get a Global Discovery Service token: AADSTS50076' }

        Connect-Maester -Service Dataverse 6>$null

        $dataverse = $script:connectionSummaryRows | Where-Object Service -eq 'Dataverse'
        $dataverse.Status | Should -Be 'Failed'
        $dataverse.Details | Should -Be 'Could not get a Global Discovery Service token: AADSTS50076'
    }

    It 'Records the Dataverse environment when the access token is issued' {
        Mock Get-MtSetting -ModuleName Maester { 'https://org123.crm.dynamics.com' } -ParameterFilter { $Name -eq 'DataverseEnvironmentUrl' }
        Mock Get-AzAccessToken -ModuleName Maester { [pscustomobject]@{ Token = 'token' } }

        Connect-Maester -Service Dataverse 6>$null

        $dataverse = $script:connectionSummaryRows | Where-Object Service -eq 'Dataverse'
        $dataverse.Status | Should -Be 'Connected'
        $dataverse.Details | Should -Be 'org123.crm.dynamics.com'
    }
}

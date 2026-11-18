BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Keep -Service All tests isolated from optional service modules that may not be installed.
    $script:createdStubs = @()
    # Mocks with a -ParameterFilter only see parameters the command declares, so give those stubs the parameters the tests filter on.
    $stubBodies = @{
        'Connect-AzAccount' = {
            [CmdletBinding()]
            param([switch]$SkipContextPopulation, [switch]$UseDeviceAuthentication, [string]$Environment, [string]$Tenant)
            $null = $PSBoundParameters
        }
        'Connect-MicrosoftTeams' = {
            [CmdletBinding()]
            param([string]$TeamsEnvironmentName, [switch]$UseDeviceAuthentication)
            $null = $PSBoundParameters
        }
        'Get-AzAccessToken' = {
            [CmdletBinding()]
            param([string]$ResourceUrl, [string]$TenantId, [switch]$AsSecureString)
            $null = $PSBoundParameters
        }
        'Connect-ADOPS' = {
            [CmdletBinding()]
            param([string]$Organization, [string]$TenantId, [string]$OAuthToken)
            $null = $PSBoundParameters
        }
        'Invoke-ADOPSRestMethod' = {
            [CmdletBinding()]
            param([string]$Uri, [string]$Method)
            $null = $PSBoundParameters
        }
        'Connect-IPPSSession' = {
            [CmdletBinding()]
            param([string]$ConnectionUri, [string]$AzureADAuthorizationEndpointUri, [string]$UserPrincipalName, [switch]$BypassMailboxAnchoring, [switch]$ShowBanner)
            $null = $PSBoundParameters
        }
    }
    foreach ($cmd in 'Get-AzContext','Connect-AzAccount','Get-AzAccessToken','Connect-ExchangeOnline','Connect-IPPSSession','Get-ConnectionInformation','Connect-MgGraph','Connect-MicrosoftTeams','Connect-ADOPS','Disconnect-ADOPS','Get-ADOPSConnection','Invoke-ADOPSRestMethod') {
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
        # -Service is completed rather than validated by a set, so pack connectors can add services.
        $line = 'Connect-Maester -Service Git'
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
        $completion.CompletionMatches.CompletionText | Should -Contain 'GitHub'
    }

    It 'Offers ActiveDirectory as a -Service option' {
        # -Service is completed rather than validated by a set, so pack connectors can add services.
        $line = 'Connect-Maester -Service Act'
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
        $completion.CompletionMatches.CompletionText | Should -Contain 'ActiveDirectory'
    }

    It 'Offers AzureDevOps as a -Service option' {
        # The report tells users to run Connect-Maester -Service AzureDevOps for skipped AZDO tests (#2740).
        $line = 'Connect-Maester -Service AzureD'
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
        $completion.CompletionMatches.CompletionText | Should -Contain 'AzureDevOps'
    }

    It 'Offers AzureDevOpsOrganization as a parameter' {
        (Get-Command Connect-Maester).Parameters.Keys | Should -Contain 'AzureDevOpsOrganization'
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
        Mock Connect-ADOPS -ModuleName Maester { throw 'Connect-ADOPS should not be called for -Service All.' }

        Connect-Maester -Service All 3>$null 6>$null

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
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

    It 'Passes the Teams environment together with -UseDeviceCode' {
        Connect-Maester -Service Teams -UseDeviceCode -TeamsEnvironmentName TeamsGCCH 6>$null

        Should -Invoke Connect-MicrosoftTeams -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $UseDeviceAuthentication -and $TeamsEnvironmentName -eq 'TeamsGCCH'
        }
        InModuleScope Maester {
            $__MtSession.TeamsUseDeviceCode | Should -BeTrue
            $__MtSession.TeamsEnvironmentName | Should -Be 'TeamsGCCH'
        }
    }

    Context 'When an Az context from another tenant already exists' {
        BeforeEach {
            Mock Get-AzContext -ModuleName Maester {
                [pscustomobject]@{
                    Account = [pscustomobject]@{ Id = 'admin@contoso.com' }
                    Tenant  = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' }
                }
            }
            Mock Connect-AzAccount -ModuleName Maester {}
        }

        It 'Signs in to the requested tenant instead of reusing the context' {
            Connect-Maester -Service Azure -TenantId '22222222-2222-2222-2222-222222222222' 6>$null

            Should -Invoke Connect-AzAccount -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Tenant -eq '22222222-2222-2222-2222-222222222222'
            }
        }

        It 'Reuses the context when its tenant is the requested one, whatever the letter case' {
            Connect-Maester -Service Azure -TenantId '11111111-1111-1111-1111-111111111111'.ToUpper() 6>$null

            Should -Invoke Connect-AzAccount -ModuleName Maester -Times 0 -Exactly
        }

        It 'Reuses the context when no tenant is requested' {
            Connect-Maester -Service Azure 6>$null

            Should -Invoke Connect-AzAccount -ModuleName Maester -Times 0 -Exactly
        }

        It 'Reuses the context when the tenant is given as a domain name, which cannot be compared with its ID' {
            $verboseOutput = Connect-Maester -Service Azure -TenantId 'contoso.onmicrosoft.com' -Verbose 4>&1 6>$null

            Should -Invoke Connect-AzAccount -ModuleName Maester -Times 0 -Exactly
            "$verboseOutput" | Should -BeLike "*cannot be compared*11111111-1111-1111-1111-111111111111*"
        }
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

    It 'Connects Security & Compliance when Exchange Online is already connected but not in -Service (#2467)' {
        # Two-step connect: an earlier call connected Exchange Online, so its session is live even though this
        # call asks only for Security & Compliance. The decision must follow the live session, not -Service.
        Mock Test-MtConnection -ModuleName Maester { $true } -ParameterFilter { $Service -contains 'ExchangeOnline' }

        Connect-Maester -Service SecurityCompliance 6>$null

        $scc = $script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance'
        $scc.Status | Should -Be 'Connected'
        $scc.Details | Should -Be 'compliance@contoso.com'
        Should -Invoke Connect-IPPSSession -ModuleName Maester -Times 1 -Exactly
    }

    It 'Reports Security & Compliance as connected right after a two-step connect (#2557)' {
        # Uses the real Test-MtConnection and Get-MtExo, so the session list the Exchange Online check caches
        # before Connect-IPPSSession must not hide the new Security & Compliance session afterwards.
        $script:mtTestIppsConnected = $false
        Mock Test-MtModuleImported -ModuleName Maester { $true } -ParameterFilter { $Name -eq 'ExchangeOnlineManagement' }
        Mock Get-ConnectionInformation -ModuleName Maester {
            [pscustomobject]@{ Name = 'ExchangeOnline_1'; IsEopSession = $false; State = 'Connected'; UserPrincipalName = 'admin@contoso.com'; ModuleName = 'tmpEXO' }
            if ($script:mtTestIppsConnected) {
                [pscustomobject]@{ Name = 'ExchangeOnlineProtection_1'; IsEopSession = $true; State = 'Connected'; UserPrincipalName = 'compliance@contoso.com'; ModuleName = 'tmpEOP' }
            }
        }
        Mock Connect-IPPSSession -ModuleName Maester { $script:mtTestIppsConnected = $true }
        InModuleScope Maester { Clear-MtExoCache }

        try {
            Connect-Maester -Service SecurityCompliance 6>$null

            ($script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance').Status | Should -Be 'Connected'
            Test-MtConnection -Service SecurityCompliance | Should -BeTrue
        } finally {
            $script:mtTestIppsConnected = $null
            InModuleScope Maester { Clear-MtExoCache }
        }
    }

    It 'Ignores a session list cached before Exchange Online connected (#2557)' {
        Mock Test-MtModuleImported -ModuleName Maester { $true } -ParameterFilter { $Name -eq 'ExchangeOnlineManagement' }
        Mock Get-ConnectionInformation -ModuleName Maester {
            [pscustomobject]@{ Name = 'ExchangeOnline_1'; IsEopSession = $false; State = 'Connected'; UserPrincipalName = 'admin@contoso.com'; ModuleName = 'tmpEXO' }
        }
        Mock Connect-IPPSSession -ModuleName Maester {}
        # An earlier check cached a list from before Exchange Online was connected.
        InModuleScope Maester { $__MtSession.ExoCache['ConnectionInformation'] = @() }

        try {
            Connect-Maester -Service SecurityCompliance 6>$null

            ($script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance').Status | Should -Be 'Connected'
            Should -Invoke Connect-IPPSSession -ModuleName Maester -Times 1 -Exactly
        } finally {
            InModuleScope Maester { Clear-MtExoCache }
        }
    }

    It 'Skips Security & Compliance when Exchange Online is neither requested nor connected (#2467)' {
        Mock Test-MtConnection -ModuleName Maester { $false } -ParameterFilter { $Service -contains 'ExchangeOnline' }

        Connect-Maester -Service SecurityCompliance 6>$null

        $scc = $script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance'
        $scc.Status | Should -Be 'Skipped'
        $scc.Details | Should -Be 'Requires an Exchange Online connection'
        Should -Invoke Connect-IPPSSession -ModuleName Maester -Times 0 -Exactly
    }

    It 'Warns rather than silently skips Security & Compliance under -Service All -UseDeviceCode (#2467)' {
        Connect-Maester -Service All -UseDeviceCode -WarningVariable deviceCodeWarnings 6>$null 3>$null

        $scc = $script:connectionSummaryRows | Where-Object Service -eq 'Security & Compliance'
        $scc.Status | Should -Be 'Skipped'
        $scc.Details | Should -Be 'Device code sign-in is not supported for Security & Compliance'
        ($deviceCodeWarnings -join "`n") | Should -Match 'device code'
        Should -Invoke Connect-IPPSSession -ModuleName Maester -Times 0 -Exactly
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

Describe 'Connect-Maester Azure DevOps' {
    BeforeEach {
        $script:savedConfigEnvironment = $env:MAESTER_CONFIG
        $env:MAESTER_CONFIG = $null
        Push-Location $TestDrive
        InModuleScope Maester {
            $__MtSession.MaesterConfig = $null
            $__MtSession.ConnectionConfig = $null
            $__MtSession.AzureDevOpsConnectionCache = $null
        }
        $script:connectionSummaryRows = $null
        Mock Write-MtConnectionSummary -ModuleName Maester { $script:connectionSummaryRows = @($Summary) }
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Get-MgContext -ModuleName Maester { [pscustomobject]@{ Account = 'admin@contoso.com'; TenantId = '00000000-0000-0000-0000-000000000001' } }
        Mock Get-AzContext -ModuleName Maester { $null }
        Mock Get-AzAccessToken -ModuleName Maester { throw 'Get-AzAccessToken should not be called without an Az context.' }
        Mock Connect-ADOPS -ModuleName Maester { @{ Identity = 'admin@contoso.com'; TenantId = 'NotSpecified'; Organization = $Organization } }
        Mock Disconnect-ADOPS -ModuleName Maester {}
        Mock Get-ADOPSConnection -ModuleName Maester { $null }
        Mock Import-Module -ModuleName Maester {} -ParameterFilter { $Name -contains 'ADOPS' }
    }

    AfterEach {
        Pop-Location
        $env:MAESTER_CONFIG = $script:savedConfigEnvironment
        InModuleScope Maester {
            $__MtSession.MaesterConfig = $null
            $__MtSession.ConnectionConfig = $null
            $__MtSession.AzureDevOpsConnectionCache = $null
        }
        Remove-Item -LiteralPath (Join-Path $TestDrive 'maester-config.json') -ErrorAction SilentlyContinue
    }

    Context 'When the ADOPS module is installed but not imported' {
        BeforeEach {
            Mock Get-Module -ModuleName Maester { $null } -ParameterFilter { $Name -contains 'ADOPS' -and -not $ListAvailable }
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS'; Version = '2.0.0' } } -ParameterFilter { $Name -contains 'ADOPS' -and $ListAvailable }
        }

        It 'Imports optional ADOPS and signs in interactively without an Az context' {
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'

            Should -Invoke Import-Module -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Name -contains 'ADOPS' -and $Global -and -not $ArgumentList
            }
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Organization -eq 'contoso' -and -not $PSBoundParameters.ContainsKey('OAuthToken')
            }
            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Connected'
            $row.Details | Should -Be 'contoso, admin@contoso.com'
        }

        It 'Passes a <TokenKind> token from an existing Az context to Connect-ADOPS' -ForEach @(
            @{ TokenKind = 'SecureString' }
            @{ TokenKind = 'string' }
        ) {
            Mock Get-AzContext -ModuleName Maester {
                [pscustomobject]@{ Account = [pscustomobject]@{ Id = 'spn@contoso.com' }; Tenant = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' } }
            }
            $token = if ($TokenKind -eq 'SecureString') { [System.Net.NetworkCredential]::new('', 'ado-token').SecurePassword } else { 'ado-token' }
            Mock Get-AzAccessToken -ModuleName Maester { [pscustomobject]@{ Token = $token } }

            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'

            Should -Invoke Get-AzAccessToken -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $ResourceUrl -eq '499b84ac-1321-427f-aa17-267ca6975798' -and $TenantId -eq '11111111-1111-1111-1111-111111111111'
            }
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Organization -eq 'contoso' -and $OAuthToken -eq 'ado-token'
            }
        }

        It 'Reads the organization from maester-config.json when -AzureDevOpsOrganization is omitted' {
            '{"GlobalSettings":{"AzureDevOpsOrganization":"fabrikam"}}' | Set-Content ./maester-config.json

            Connect-Maester -Service AzureDevOps

            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'fabrikam' }
        }

        It 'Prefers an explicit organization to the loaded config' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ AzureDevOpsOrganization = 'fabrikam' } }
            }
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'contoso' }
        }

        It 'Applies the tenant organization when GitHub connects <Sequence>' -ForEach @(
            @{ Sequence = 'in a prior call' }
            @{ Sequence = 'in the same call' }
        ) {
            '{"GlobalSettings":{"GitHubOrganization":"test-org","AzureDevOpsOrganization":"base-org"}}' | Set-Content ./maester-config.json
            $tenantFile = Join-Path $TestDrive 'maester-config.11111111-2222-3333-4444-555555555555.json'
            '{"GlobalSettings":{"AzureDevOpsOrganization":"tenant-org"}}' | Set-Content $tenantFile
            Mock Invoke-WebRequest -ModuleName Maester {
                [pscustomobject]@{ Content = '{"login":"testuser","state":"active","role":"admin","enabled_repositories":"all"}'; StatusCode = 200 }
            }
            $savedToken = $env:MAESTER_GITHUB_TOKEN
            try {
                $env:MAESTER_GITHUB_TOKEN = 'test-token'
                if ($Sequence -eq 'in a prior call') {
                    Connect-MtGitHub
                    Connect-Maester -Service AzureDevOps -TenantId '11111111-2222-3333-4444-555555555555'
                } else {
                    Connect-Maester -Service GitHub,AzureDevOps -TenantId '11111111-2222-3333-4444-555555555555'
                }

                InModuleScope Maester { $__MtSession.GitHubConnection.Connected | Should -BeTrue }
                Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly
                Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                    $Organization -eq 'tenant-org' -and $TenantId -eq '11111111-2222-3333-4444-555555555555'
                }
            } finally {
                $env:MAESTER_GITHUB_TOKEN = $savedToken
                Remove-Item -LiteralPath $tenantFile
            }
        }

        It 'Preserves an explicit run configuration supplied as <ConfigKind>' -ForEach @(
            @{ ConfigKind = 'an object' }
            @{ ConfigKind = 'a file' }
        ) {
            $tenantFile = Join-Path $TestDrive 'maester-config.11111111-2222-3333-4444-555555555555.json'
            '{"GlobalSettings":{"AzureDevOpsOrganization":"tenant-org"}}' | Set-Content $tenantFile
            '{"GlobalSettings":{"AzureDevOpsOrganization":"explicit-org"}}' | Set-Content ./maester-config.json
            try {
                Connect-Maester -Service AzureDevOps -TenantId '11111111-2222-3333-4444-555555555555'
                InModuleScope Maester -Parameters @{ ConfigKind = $ConfigKind; ConfigPath = (Join-Path $TestDrive 'maester-config.json') } {
                    param($ConfigKind, $ConfigPath)
                    $config = if ($ConfigKind -eq 'a file') { $ConfigPath } else { @{ GlobalSettings = @{ AzureDevOpsOrganization = 'explicit-org' } } }
                    $__MtSession.MaesterConfig = Resolve-MtRunConfig -Config $config
                }
                Connect-Maester -Service AzureDevOps -TenantId '11111111-2222-3333-4444-555555555555'
                Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'explicit-org' }
            } finally {
                Remove-Item -LiteralPath $tenantFile
            }
        }

        It 'Discovers the new tenant organization when reconnecting' {
            $tenantFiles = @('maester-config.11111111-2222-3333-4444-555555555555.json', 'maester-config.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.json')
            '{"GlobalSettings":{"AzureDevOpsOrganization":"first-org"}}' | Set-Content $tenantFiles[0]
            '{"GlobalSettings":{"AzureDevOpsOrganization":"second-org"}}' | Set-Content $tenantFiles[1]
            try {
                Connect-Maester -Service AzureDevOps -TenantId '11111111-2222-3333-4444-555555555555'
                Connect-Maester -Service AzureDevOps -TenantId 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'first-org' }
                Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'second-org' }
            } finally {
                Remove-Item -LiteralPath $tenantFiles
            }
        }

        It 'Uses an explicit tenant for both token acquisition and ADOPS' {
            Mock Get-AzContext -ModuleName Maester { [pscustomobject]@{ Account = @{ Id = 'user' }; Tenant = @{ Id = 'old-tenant' } } }
            Mock Get-AzAccessToken -ModuleName Maester { [pscustomobject]@{ Token = 'ado-token' } }
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso' -TenantId 'requested-tenant'
            Should -Invoke Get-AzAccessToken -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $TenantId -eq 'requested-tenant' }
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $TenantId -eq 'requested-tenant' -and $OAuthToken -eq 'ado-token' }
        }

        It 'Reuses the Azure sign-in established in the same call' {
            $script:azureSignedIn = $false
            Mock Connect-AzAccount -ModuleName Maester { $script:azureSignedIn = $true }
            Mock Get-AzContext -ModuleName Maester {
                if ($script:azureSignedIn) { [pscustomobject]@{ Account = @{ Id = 'user' }; Tenant = @{ Id = 'tenant' } } }
            }
            Mock Get-AzAccessToken -ModuleName Maester { [pscustomobject]@{ Token = 'ado-token' } }
            Connect-Maester -Service AzureDevOps,Azure -AzureDevOpsOrganization 'contoso'
            Should -Invoke Connect-AzAccount -ModuleName Maester -Times 1 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $OAuthToken -eq 'ado-token' }
        }

        It 'Invalidates a positive connection probe when reconnecting fails' {
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'old-org' } }
            $script:adoOrganization = 'old-org'
            Mock Disconnect-ADOPS -ModuleName Maester { $script:adoOrganization = $null }
            Mock Get-ADOPSConnection -ModuleName Maester {
                if ($script:adoOrganization) { @{ Organization = $script:adoOrganization } }
            }
            Mock Connect-ADOPS -ModuleName Maester { throw 'sign-in failed' }
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'new-org'
            Test-MtConnection -Service AzureDevOps | Should -BeFalse
            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Failed'
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 1 -Exactly
            # A new run clears the probe cache; the provider must no longer expose the old org either.
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = $null }
            Test-MtConnection -Service AzureDevOps | Should -BeFalse
            $script:adoOrganization | Should -BeNullOrEmpty
        }

        It 'Clears the previous organization when token acquisition fails' {
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'old-org' } }
            $script:adoOrganization = 'old-org'
            Mock Get-AzContext -ModuleName Maester { [pscustomobject]@{ Account = @{ Id = 'user' }; Tenant = @{ Id = 'tenant' } } }
            Mock Get-AzAccessToken -ModuleName Maester { throw 'token failed' }
            Mock Disconnect-ADOPS -ModuleName Maester { $script:adoOrganization = $null }
            Mock Get-ADOPSConnection -ModuleName Maester {
                if ($script:adoOrganization) { @{ Organization = $script:adoOrganization } }
            }
            # A surviving session must pass the probe so a request failure cannot hide it.
            Mock Invoke-ADOPSRestMethod -ModuleName Maester { @{} }

            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'new-org'

            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Failed'
            $row.Details | Should -Be 'token failed'
            Test-MtConnection -Service AzureDevOps | Should -BeFalse
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            # A new run clears the probe cache; neither the probe nor ADOPS may recover the old organization.
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = $null }
            Test-MtConnection -Service AzureDevOps | Should -BeFalse
            InModuleScope Maester { Get-ADOPSConnection } | Should -BeNullOrEmpty
            $script:adoOrganization | Should -BeNullOrEmpty
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 1 -Exactly
        }

        It 'Keeps a verified ADOPS session when the configuration names no organization' {
            # No organization means nothing to connect to, so a session from Connect-ADOPS is kept and reported,
            # not torn down. Test-MtConnection verifies it first, so the summary names the organization the tests read.
            '{"GlobalSettings":{}}' | Set-Content ./maester-config.json
            $script:adoOrganization = 'old-org'
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS' } } -ParameterFilter { $Name -contains 'ADOPS' }
            Mock Invoke-ADOPSRestMethod -ModuleName Maester { @{} }
            Mock Disconnect-ADOPS -ModuleName Maester { $script:adoOrganization = $null }
            Mock Get-ADOPSConnection -ModuleName Maester {
                if ($script:adoOrganization) { @{ Organization = $script:adoOrganization } }
            }

            Connect-Maester -Service AzureDevOps -WarningVariable adoWarnings -ErrorVariable adoErrors -ErrorAction SilentlyContinue 3>$null

            $adoErrors | Should -BeNullOrEmpty
            ($adoWarnings -join "`n") | Should -Match "existing ADOPS session to 'old-org'"
            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Connected'
            $row.Details | Should -Be 'old-org (existing ADOPS session; no organization specified)'
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 0 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            $script:adoOrganization | Should -Be 'old-org'
            # The next run resets the probe cache and still finds the same session.
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = $null }
            Test-MtConnection -Service AzureDevOps | Should -BeTrue
        }

        It 'Reports an invalid configuration file as a failure without disconnecting ADOPS' {
            '{invalid' | Set-Content ./maester-config.json
            $script:adoOrganization = 'old-org'
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS' } } -ParameterFilter { $Name -contains 'ADOPS' }
            Mock Invoke-ADOPSRestMethod -ModuleName Maester { @{} }
            Mock Disconnect-ADOPS -ModuleName Maester { $script:adoOrganization = $null }
            Mock Get-ADOPSConnection -ModuleName Maester {
                if ($script:adoOrganization) { @{ Organization = $script:adoOrganization } }
            }

            Connect-Maester -Service AzureDevOps -ErrorAction SilentlyContinue

            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Failed'
            $row.Details | Should -Match 'not valid JSON'
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 0 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            $script:adoOrganization | Should -Be 'old-org'
        }

        It 'Keeps an existing ADOPS session and connects the other services when no organization is given' {
            $script:adoOrganization = 'old-org'
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS' } } -ParameterFilter { $Name -contains 'ADOPS' }
            Mock Invoke-ADOPSRestMethod -ModuleName Maester { @{} }
            Mock Get-ADOPSConnection -ModuleName Maester { @{ Organization = $script:adoOrganization } }

            Connect-Maester -Service Graph, AzureDevOps -WarningVariable adoWarnings -ErrorVariable adoErrors 3>$null

            $adoErrors | Should -BeNullOrEmpty
            ($adoWarnings -join "`n") | Should -Match 'No Azure DevOps organization specified'
            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Connected'
            ($script:connectionSummaryRows | Where-Object Service -eq 'Microsoft Graph').Status | Should -Be 'Connected'
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 0 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
        }

        It 'Skips without disconnecting when no organization is given and the persisted ADOPS session no longer works' {
            # Get-ADOPSConnection reads ~/.ADOPS/Config.json, which can name an organization whose token is gone.
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS' } } -ParameterFilter { $Name -contains 'ADOPS' }
            Mock Get-ADOPSConnection -ModuleName Maester { @{ Organization = 'stale-org' } }
            Mock Invoke-ADOPSRestMethod -ModuleName Maester { throw 'TF400813: The user is not authorized to access this resource.' }

            Connect-Maester -Service AzureDevOps -ErrorVariable adoErrors -ErrorAction SilentlyContinue

            # The probe's own caught exception is also recorded in -ErrorVariable, so look for the one Connect-Maester writes.
            @($adoErrors | Where-Object { "$_" -match 'No Azure DevOps organization specified' }).Count | Should -Be 1
            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Skipped'
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 0 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache | Should -Be 'NotConnected' }
        }

        It 'Disconnects the previous ADOPS session only when a new sign-in is attempted' {
            $script:adoOrganization = 'old-org'
            Mock Disconnect-ADOPS -ModuleName Maester { $script:adoOrganization = $null }
            Mock Get-ADOPSConnection -ModuleName Maester {
                if ($script:adoOrganization) { @{ Organization = $script:adoOrganization } }
            }

            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'new-org'

            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 1 -Exactly
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'new-org' }
            $script:adoOrganization | Should -BeNullOrEmpty
        }

        It 'Reports the actual failure when <MissingCommand> is unavailable despite ADOPS being installed' -ForEach @(
            @{ MissingCommand = 'Get-AzAccessToken' }
            @{ MissingCommand = 'Connect-ADOPS' }
        ) {
            Mock Get-AzContext -ModuleName Maester { [pscustomobject]@{ Account = @{ Id = 'user' }; Tenant = @{ Id = 'tenant' } } }
            Mock Get-AzAccessToken -ModuleName Maester { [pscustomobject]@{ Token = 'ado-token' } }
            Mock $MissingCommand -ModuleName Maester { throw [System.Management.Automation.CommandNotFoundException]::new("$MissingCommand is unavailable.") }

            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'

            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Failed'
            $row.Details | Should -Be "$MissingCommand is unavailable."
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache | Should -Be 'NotConnected' }
        }

        It 'Allows a fresh connection probe after a successful retry' {
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache = 'NotConnected' }
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'
            InModuleScope Maester { $__MtSession.AzureDevOpsConnectionCache | Should -BeNullOrEmpty }
        }

        It 'Reuses an already imported ADOPS module' {
            Mock Get-Module -ModuleName Maester { [pscustomobject]@{ Name = 'ADOPS' } } -ParameterFilter { $Name -contains 'ADOPS' -and -not $ListAvailable }
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso'
            Should -Invoke Import-Module -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $Name -contains 'ADOPS' }
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 1 -Exactly
        }

        It 'Records a failed sign-in and still connects the other services' {
            Mock Connect-ADOPS -ModuleName Maester { throw "The connected account does not have access to the organization 'contoso'." }

            Connect-Maester -Service Graph, AzureDevOps -AzureDevOpsOrganization 'contoso'

            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Failed'
            ($script:connectionSummaryRows | Where-Object Service -eq 'Microsoft Graph').Status | Should -Be 'Connected'
        }

        It 'Writes an error when Azure DevOps is the only service and no organization is given' {
            Connect-Maester -Service AzureDevOps -ErrorVariable adoErrors -ErrorAction SilentlyContinue

            $adoErrors.Count | Should -Be 1
            "$($adoErrors[0])" | Should -Match 'AzureDevOpsOrganization'
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            Should -Invoke Disconnect-ADOPS -ModuleName Maester -Times 0 -Exactly
            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Skipped'
        }
    }

    Context 'When the ADOPS module is not installed' {
        BeforeEach {
            Mock Get-Module -ModuleName Maester { $null } -ParameterFilter { $Name -contains 'ADOPS' }
        }

        It 'Warns and still connects the other services' {
            Connect-Maester -Service Graph, AzureDevOps -AzureDevOpsOrganization 'contoso' -WarningVariable adoWarnings -ErrorVariable adoErrors 3>$null

            $adoErrors | Should -BeNullOrEmpty
            ($adoWarnings -join "`n") | Should -Match 'Install-Module ADOPS'
            Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly
            Should -Invoke Import-Module -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $Name -contains 'ADOPS' }
            Should -Invoke Connect-ADOPS -ModuleName Maester -Times 0 -Exactly
            $row = $script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps'
            $row.Status | Should -Be 'Not installed'
            $row.Details | Should -Be 'Run: Install-Module ADOPS -Scope CurrentUser'
        }

        It 'Writes an error when Azure DevOps is the only service' {
            Connect-Maester -Service AzureDevOps -AzureDevOpsOrganization 'contoso' -WarningVariable adoWarnings -ErrorVariable adoErrors -ErrorAction SilentlyContinue 3>$null

            $adoWarnings | Should -BeNullOrEmpty
            $adoErrors.Count | Should -Be 1
            $adoErrors[0].CategoryInfo.Category | Should -Be 'NotInstalled'
            "$($adoErrors[0])" | Should -Match 'Install-Module ADOPS'
            ($script:connectionSummaryRows | Where-Object Service -eq 'Azure DevOps').Status | Should -Be 'Not installed'
        }
    }
}

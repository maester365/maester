function Connect-Maester {
   <#
.SYNOPSIS
   Helper method to connect to Microsoft Graph using Connect-MgGraph with the required permission scopes as well as other services such as Azure, Exchange Online, and GitHub.

.DESCRIPTION
   Use this cmdlet to connect to Microsoft Graph and the Microsoft 365 services that Maester can assess. By default, it connects to Microsoft Graph. Use -Service All to connect to Microsoft 365 services, including Microsoft Graph, Azure, Exchange Online, Security & Compliance, Microsoft Teams, SharePoint Online, and Dataverse.

   Non-Microsoft 365 services such as Active Directory and GitHub are not included in -Service All and must be explicitly specified.

   When it finishes, Connect-Maester shows a summary table with the status of each service it tried (Connected, Skipped, Failed or Not installed) and a short detail. Use -Verbose to see the step-by-step messages for each connection.

   This command is completely optional if you are already connected to Microsoft Graph and other services using Connect-MgGraph with the required scopes.

   ```
   Connect-MgGraph -Scopes (Get-MtGraphScope)
   ```

.EXAMPLE
   Connect-Maester

   Connects only to Microsoft Graph by default.

.EXAMPLE
   Connect-Maester -Service Graph,Teams

   Connects to Microsoft Graph and Microsoft Teams.

.EXAMPLE
   Connect-Maester -Service Graph,GitHub -GitHubOrganization 'mycompany'

   Connects to Microsoft Graph and GitHub. GitHub sign-in is handled by Connect-MtGitHub using the Maester GitHub App device flow by default, including guided organization app install/approval when required. Automation can still use MAESTER_GITHUB_TOKEN or GH_TOKEN.

.EXAMPLE
   Connect-Maester -Service ActiveDirectory

   Validates connectivity to the current Active Directory domain. Active Directory must be explicitly selected and is not included in -Service All.

.EXAMPLE
   Connect-Maester -Service Azure,Graph

   Connects to Microsoft Graph and Azure.

.EXAMPLE
   Connect-Maester -Service Dataverse,Graph

   Connects to Microsoft Graph and the Dataverse API for Copilot Studio security tests. The Dataverse connection uses the Az.Accounts module. The Copilot Studio environment is auto-discovered via the Global Discovery Service, or can be explicitly set with DataverseEnvironmentUrl in maester-config.json.

.EXAMPLE
   Connect-Maester -UseDeviceCode

   Connects to Microsoft Graph and Azure using the device code flow. This will open a browser window to prompt for authentication.

.EXAMPLE
   Connect-Maester -SendMail

   Connects to Microsoft Graph with the Mail.Send scope.

.EXAMPLE
   Connect-Maester -SendTeamsMessage

   Connects to Microsoft Graph with the ChannelMessage.Send scope.

.EXAMPLE
   Connect-Maester -Privileged

   Connects to Microsoft Graph with additional privileged scopes such as **RoleEligibilitySchedule.ReadWrite.Directory** that are required for querying Global Administrator roles in Privileged Identity Management.

.EXAMPLE
   Connect-Maester -IncludePreview

   Connects to Microsoft Graph with the additional scopes required by preview tests.

.EXAMPLE
   Connect-Maester -Environment USGov -AzureEnvironment AzureUSGovernment -ExchangeEnvironmentName O365USGovGCCHigh

   Connects to US Government environments for Microsoft Graph, Azure, and Exchange Online.

.EXAMPLE
   Connect-Maester -Environment USGovDoD -AzureEnvironment AzureUSGovernment -ExchangeEnvironmentName O365USGovDoD

   Connects to US Department of Defense (DoD) environments for Microsoft Graph, Azure, and Exchange Online.

.EXAMPLE
   Connect-Maester -Environment China -AzureEnvironment AzureChinaCloud -ExchangeEnvironmentName O365China

   Connects to China environments for Microsoft Graph, Azure, and Exchange Online.

.EXAMPLE
   Connect-Maester -GraphClientId 'f45ec3ad-32f0-4c06-8b69-47682afe0216'

   Connects using a custom application with client ID f45ec3ad-32f0-4c06-8b69-47682afe0216

.EXAMPLE
   Connect-Maester -ClientTimeout 900

   Connects to Microsoft Graph with an HTTP client timeout of 900 seconds. This can be useful for long-running tests in large tenants.

.EXAMPLE
   Connect-Maester -Service Graph,SharePointOnline -SharePointClientId '<Client ID>'

   Connects to Microsoft Graph and SharePoint Online using the specified PnP app registration. The SharePoint admin URL is auto-discovered from the tenant's initial domain via the Graph API. Optionally, specify -SharePointAdminUrl to override the auto-discovered URL (e.g. for custom domain or government cloud tenants).

.EXAMPLE
   Connect-Maester -Service SharePointOnline -SharePointClientId 'f45ec3ad-32f0-4c06-8b69-47682afe0216' -SharePointAdminUrl 'https://contoso-admin.sharepoint.com'

   Connects to SharePoint Online using the specified client ID and admin URL.

.LINK
   https://maester.dev/docs/commands/Connect-Maester
#>
   [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
   [Alias('Connect-MtGraph', 'Connect-MtMaester')]
   [CmdletBinding()]
   param(
      # If specified, the cmdlet will include the scope to send email (Mail.Send).
      [switch] $SendMail,

      # If specified, the cmdlet will include the scope to send a channel message in Teams (ChannelMessage.Send).
      [switch] $SendTeamsMessage,

      # If specified, the cmdlet will include the scopes for read write API endpoints. This is currently required for querying Global Administrator roles in PIM.
      [switch] $Privileged,

      # If specified, the cmdlet will include scopes required by preview tests.
      [switch] $IncludePreview,

      # If specified, the cmdlet will use the device code flow to authenticate to Graph and Azure.
      # This will open a browser window to prompt for authentication and is useful for non-interactive sessions and on Windows when SSO is not desired.
      [switch] $UseDeviceCode,

      # The environment to connect to. Default is Global. Supported values include China, Germany, Global, USGov, USGovDoD.
      [ValidateSet('China', 'Germany', 'Global', 'USGov', 'USGovDoD')]
      [string]$Environment = 'Global',

      # The Azure environment to connect to. Default is AzureCloud. Supported values include AzureChinaCloud, AzureCloud, AzureUSGovernment.
      [ValidateSet('AzureChinaCloud', 'AzureCloud', 'AzureUSGovernment')]
      [string]$AzureEnvironment = 'AzureCloud',

      # The Exchange environment to connect to. Default is O365Default. Supported values include O365China, O365Default, O365GermanyCloud, O365USGovDoD, O365USGovGCCHigh.
      [ValidateSet('O365China', 'O365Default', 'O365GermanyCloud', 'O365USGovDoD', 'O365USGovGCCHigh')]
      [string]$ExchangeEnvironmentName = 'O365Default',

      # The Teams environment to connect to. Default is O365Default.
      [ValidateSet('TeamsChina', 'TeamsGCCH', 'TeamsDOD')]
      [string]$TeamsEnvironmentName = $null, #ToValidate: Don't use this parameter, this is the default.

      # The services to connect to such as Active Directory, Azure, Dataverse (for Copilot Studio tests), EXO, GitHub, and SharePoint Online. Default is Graph. Active Directory and GitHub are not included in All and must be explicitly specified.
      [ValidateSet('ActiveDirectory', 'All', 'Azure', 'Dataverse', 'ExchangeOnline', 'GitHub', 'Graph', 'SecurityCompliance', 'Teams', 'SharePointOnline')]
      [string[]]$Service = 'Graph',

      # The Tenant ID to connect to, if not specified the sign-in user's default tenant is used.
      [string]$TenantId,

      # The Client ID of the app to connect to for Graph. If not specified, the default Graph PowerShell CLI enterprise app will be used. Reference on how to create an enterprise app: https://learn.microsoft.com/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0#use-delegated-access-with-a-custom-application-for-microsoft-graph-powershell
      [string]$GraphClientId,

      # The Microsoft Graph HTTP client timeout in seconds. When omitted, the Microsoft Graph PowerShell SDK default is used.
      [double]$ClientTimeout,

      # The Client ID of the PnP Entra ID app for SharePoint Online. Required when Service includes SharePointOnline.
      # Use Register-PnPEntraIDAppForInteractiveLogin to create a dedicated app, or reuse an existing Maester app
      # registration by adding an http://localhost redirect URI and AllSites.FullControl delegated SharePoint permission.
      [string]$SharePointClientId,

      # The SharePoint admin center URL to connect to when using the SharePointOnline service (e.g. https://contoso-admin.sharepoint.com).
      # If not specified, the URL is auto-discovered from the tenant's initial domain via the Microsoft Graph API.
      [string]$SharePointAdminUrl,

      # The certificate thumbprint for app-only authentication to SharePoint Online.
      # Use together with -SharePointClientId and -TenantId for non-interactive/automation scenarios.
      # The certificate must be installed in the current user's certificate store.
      [string]$SharePointCertificateThumbprint,

      # The GitHub organization login name to connect to when Service includes GitHub.
      [string]$GitHubOrganization,

      # The Active Directory forest DNS name to discover when Service includes ActiveDirectory.
      [object]$ActiveDirectoryForest,

      # The Active Directory domain DNS name to discover when Service includes ActiveDirectory.
      [object]$ActiveDirectoryDomain,

      # The Active Directory domain controller to connect to when Service includes ActiveDirectory.
      [object]$ActiveDirectoryServer,

      # The credential used for the Active Directory LDAP connection.
      [System.Management.Automation.PSCredential]$ActiveDirectoryCredential,

      # The authentication mode used for the Active Directory LDAP connection.
      [Alias('AuthMode')]
      [ValidateSet('Negotiate', 'Kerberos', 'Ntlm', 'Basic')]
      [string]$ActiveDirectoryAuthMode = 'Negotiate',

      # The TLS mode used for the Active Directory LDAP connection. Auto tries LDAPS before StartTLS.
      [Alias('TlsMode')]
      [ValidateSet('Auto', 'Ldaps', 'StartTls')]
      [string]$ActiveDirectoryTlsMode = 'Auto'
   )

   $__MtSession.Connections = $Service

   # Record the outcome of each service so a single summary table can be shown at the end.
   # Step-by-step explanations go to the verbose stream; the table carries what the user needs to act on.
   $connectionSummary = [System.Collections.Generic.List[object]]::new()
   function Add-ConnectionResult ([string] $Name, [string] $Status, [string] $Details) {
      $connectionSummary.Add([PSCustomObject]@{ Service = $Name; Status = $Status; Details = $Details })
   }
   function Get-ErrorSummary ($ErrorRecord) {
      $message = if ($ErrorRecord.Exception) { $ErrorRecord.Exception.Message } else { "$ErrorRecord" }
      ("$message" -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
   }

   # Use an explicit module processing order so Microsoft Graph always connects before PnP.PowerShell.
   # This avoids relying on Get-ModuleImportOrder, which may reorder modules by bundled DLL version.
   $OrderedImport = @('Az.Accounts', 'ExchangeOnlineManagement', 'Microsoft.Graph.Authentication', 'MicrosoftTeams', 'PnP.PowerShell')
   switch ($OrderedImport) {

      'Az.Accounts' {
         if ($Service -contains 'Azure' -or $Service -contains 'Dataverse' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Azure'
            $azureConnected = $false
            try {
               # Skip Connect-AzAccount if there is already an active Az context
               # This preserves sessions from federated credentials, managed identity, or prior Connect-AzAccount calls
               $existingContext = Get-AzContext -ErrorAction SilentlyContinue
               if ($existingContext) {
                  Write-Verbose "Using existing Az context for account '$($existingContext.Account.Id)'"
               } else {
                  $azWarning = @()
                  if ($TenantId) {
                     Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment -Tenant $TenantId -WarningAction SilentlyContinue -WarningVariable azWarning -ErrorAction Stop | Out-Null
                  } else {
                     Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment -WarningAction SilentlyContinue -WarningVariable azWarning -ErrorAction Stop | Out-Null
                  }
                  if ($azWarning.Count -gt 0) {
                     foreach ($warning in $azWarning) {
                        Write-Verbose $warning.Message
                     }
                  }
                  $existingContext = Get-AzContext -ErrorAction SilentlyContinue
               }
               $azureConnected = $true
               Add-ConnectionResult -Name 'Azure' -Status 'Connected' -Details $existingContext.Account.Id
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Verbose 'The Azure PowerShell module is not installed. For more information see https://learn.microsoft.com/powershell/azure/install-azure-powershell'
               Add-ConnectionResult -Name 'Azure' -Status 'Not installed' -Details 'Run: Install-Module Az.Accounts -Scope CurrentUser'
            } catch {
               Write-Verbose "Failed to connect to Azure: $($_.Exception.Message)"
               Add-ConnectionResult -Name 'Azure' -Status 'Failed' -Details (Get-ErrorSummary $_)
            }

            # Resolve, parse, and validate the Dataverse environment at connect time.
            # The resolved API base URL, resource URL, and environment ID are stored in
            # session variables for use by Get-MtAIAgentInfo at test time.
            if ($Service -contains 'Dataverse' -or $Service -contains 'All') {
               if (-not $azureConnected) {
                  Add-ConnectionResult -Name 'Dataverse' -Status 'Skipped' -Details 'Requires an Azure connection'
               } else {
                  $dataverseDiscoveryError = $null
                  try {
                     # Step 1: Determine the Dataverse environment URL (explicit config or auto-discover)
                     $dataverseUrl = Get-MtSetting -Name 'DataverseEnvironmentUrl'
                     if ([string]::IsNullOrEmpty($dataverseUrl)) {
                        Write-Verbose "No DataverseEnvironmentUrl configured. Auto-discovering via Global Discovery Service."
                        $dataverseUrl = Get-MtDataverseEnvironmentUrl
                     } else {
                        Write-Verbose "Using configured DataverseEnvironmentUrl: $dataverseUrl"
                     }
                  } catch {
                     $dataverseUrl = $null
                     $dataverseDiscoveryError = $_
                  }

                  if ($dataverseDiscoveryError) {
                     Write-Verbose "Dataverse environment discovery failed: $($dataverseDiscoveryError.Exception.Message)"
                     Add-ConnectionResult -Name 'Dataverse' -Status 'Failed' -Details (Get-ErrorSummary $dataverseDiscoveryError)
                  } elseif ([string]::IsNullOrEmpty($dataverseUrl)) {
                     Write-Verbose "No Dataverse environment found. Copilot Studio agent security tests will be skipped. Configure 'DataverseEnvironmentUrl' in maester-config.json GlobalSettings to specify an environment explicitly."
                     Add-ConnectionResult -Name 'Dataverse' -Status 'Skipped' -Details 'No environment found, set DataverseEnvironmentUrl in maester-config.json'
                  } else {
                     # Step 2: Normalize and parse the URL into resource URL and API base URL
                     $dataverseUrl = $dataverseUrl.TrimEnd('/')
                     if ($dataverseUrl -notmatch '^https?://') {
                        $dataverseUrl = "https://$dataverseUrl"
                     }

                     # Resource URL: environment host without '.api.' (used for token acquisition)
                     $resourceUrl = $dataverseUrl -replace '\.api\.', '.'
                     # API URL: insert .api. after the hostname prefix (used for OData calls)
                     # e.g. https://org5acae060.crm19.dynamics.com -> https://org5acae060.api.crm19.dynamics.com
                     $apiUrl = $resourceUrl -replace '(https://[^.]+)\.', '$1.api.'
                     $apiBase = "$apiUrl/api/data/v9.2"
                     $environmentId = $resourceUrl -replace 'https?://', ''

                     # Step 3: Validate token acquisition for the resolved environment
                     try {
                        $tokenResult = Get-AzAccessToken -ResourceUrl $resourceUrl -ErrorAction Stop
                        if ($tokenResult) {
                           Write-Verbose "Successfully obtained Dataverse access token for $resourceUrl"
                        }

                        # Store resolved values in session for Get-MtAIAgentInfo
                        $__MtSession.DataverseApiBase = $apiBase
                        $__MtSession.DataverseResourceUrl = $resourceUrl
                        $__MtSession.DataverseEnvironmentId = $environmentId
                        Add-ConnectionResult -Name 'Dataverse' -Status 'Connected' -Details $environmentId
                     } catch {
                        Write-Verbose "Failed to obtain Dataverse access token for '$resourceUrl'. Ensure the account has permissions to access the Copilot Studio environment via the Dataverse API. Error: $($_.Exception.Message)"
                        Add-ConnectionResult -Name 'Dataverse' -Status 'Failed' -Details "No access token for $environmentId`: $(Get-ErrorSummary $_)"
                     }
                  }
               }
            }
         }
      }

      'ExchangeOnlineManagement' {
         $exchangeModuleInstalled = $true
         if ($Service -contains 'ExchangeOnline' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Exchange Online'
            if ($UseDeviceCode -and $PSVersionTable.PSEdition -eq 'Desktop') {
               Write-Verbose 'The Exchange Online module in Windows PowerShell does not support device code flow authentication. Use the Exchange Online module in PowerShell 7.'
               Add-ConnectionResult -Name 'Exchange Online' -Status 'Skipped' -Details 'Device code sign-in needs PowerShell 7 for Exchange Online'
            } else {
               try {
                  if ( $UseDeviceCode ) {
                     Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ExchangeEnvironmentName $ExchangeEnvironmentName -ErrorAction Stop
                  } else {
                     Connect-ExchangeOnline -ShowBanner:$false -ExchangeEnvironmentName $ExchangeEnvironmentName -ErrorAction Stop
                  }
                  $exchangeUpn = Get-ConnectionInformation -ErrorAction SilentlyContinue |
                     Where-Object { $_.IsEopSession -ne $true -and $_.State -eq 'Connected' } |
                     Select-Object -ExpandProperty UserPrincipalName -First 1 -ErrorAction SilentlyContinue
                  Add-ConnectionResult -Name 'Exchange Online' -Status 'Connected' -Details $exchangeUpn
               } catch [Management.Automation.CommandNotFoundException] {
                  Write-Verbose 'The Exchange Online module is not installed. For more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2'
                  Add-ConnectionResult -Name 'Exchange Online' -Status 'Not installed' -Details 'Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser'
                  $exchangeModuleInstalled = $false
               } catch {
                  Write-Verbose "Failed to connect to Exchange Online: $($_.Exception.Message)"
                  Add-ConnectionResult -Name 'Exchange Online' -Status 'Failed' -Details (Get-ErrorSummary $_)
               }
            }
         }

         if ($Service -contains 'SecurityCompliance' -or $Service -contains 'All') {
            $Environments = @{
               'O365China'        = @{
                  ConnectionUri    = 'https://ps.compliance.protection.partner.outlook.cn/powershell-liveid'
                  AuthZEndpointUri = 'https://login.chinacloudapi.cn/common'
               }
               'O365GermanyCloud' = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
               'O365Default'      = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
               'O365USGovGCCHigh' = @{
                  ConnectionUri    = 'https://ps.compliance.protection.office365.us/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.us/common'
               }
               'O365USGovDoD'     = @{
                  ConnectionUri    = 'https://l5.ps.compliance.protection.office365.us/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.us/common'
               }
               Default            = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
            }
            Write-Verbose 'Connecting to Microsoft Security & Compliance PowerShell'
            $securityComplianceConnected = $false
            if ($Service -notcontains 'ExchangeOnline' -and $Service -notcontains 'All') {
               Write-Verbose 'The Security & Compliance module is dependent on the Exchange Online module. For more information see https://learn.microsoft.com/powershell/exchange/connect-to-scc-powershell'
               Add-ConnectionResult -Name 'Security & Compliance' -Status 'Skipped' -Details 'Requires ExchangeOnline in -Service'
            } elseif ($UseDeviceCode) {
               Write-Verbose 'The Security & Compliance module does not support device code flow authentication.'
               Add-ConnectionResult -Name 'Security & Compliance' -Status 'Skipped' -Details 'Device code sign-in is not supported for Security & Compliance'
            } elseif (-not $exchangeModuleInstalled) {
               Add-ConnectionResult -Name 'Security & Compliance' -Status 'Not installed' -Details 'Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser'
            } else {
               try {
                  Connect-IPPSSession -BypassMailboxAnchoring -ConnectionUri $Environments[$ExchangeEnvironmentName].ConnectionUri -AzureADAuthorizationEndpointUri $Environments[$ExchangeEnvironmentName].AuthZEndpointUri -ShowBanner:$false -ErrorAction Stop
                  $securityComplianceConnected = $true
                  $securityComplianceUpn = Get-ConnectionInformation -ErrorAction SilentlyContinue |
                     Where-Object { $_.IsEopSession -eq $true -and $_.State -eq 'Connected' } |
                     Select-Object -ExpandProperty UserPrincipalName -First 1 -ErrorAction SilentlyContinue
                  Add-ConnectionResult -Name 'Security & Compliance' -Status 'Connected' -Details $securityComplianceUpn
               } catch [Management.Automation.CommandNotFoundException] {
                  Write-Verbose 'The Exchange Online module is not installed. For more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2'
                  Add-ConnectionResult -Name 'Security & Compliance' -Status 'Not installed' -Details 'Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser'
               } catch {
                  Write-Verbose "The first Security & Compliance connection attempt failed: $($_.Exception.Message)"
                  # Cache the connection information to avoid multiple calls to Get-ConnectionInformation. See https://github.com/maester365/maester/pull/1207
                  $ExoUPN = Get-MtExo -Request ConnectionInformation | Select-Object -ExpandProperty UserPrincipalName -First 1 -ErrorAction SilentlyContinue
                  if ($ExoUPN) {
                     Write-Verbose "Attempting to connect to the Security & Compliance PowerShell using UPN '$ExoUPN' derived from the ExchangeOnline connection."
                     try {
                        Connect-IPPSSession -BypassMailboxAnchoring -UserPrincipalName $ExoUPN -ShowBanner:$false -ErrorAction Stop
                        $securityComplianceConnected = $true
                        Add-ConnectionResult -Name 'Security & Compliance' -Status 'Connected' -Details "Using UPN $ExoUPN from Exchange Online"
                     } catch {
                        Write-Verbose "Failed to connect to the Security & Compliance PowerShell: $($_.Exception.Message)"
                        Add-ConnectionResult -Name 'Security & Compliance' -Status 'Failed' -Details (Get-ErrorSummary $_)
                     }
                  } else {
                     Add-ConnectionResult -Name 'Security & Compliance' -Status 'Failed' -Details 'Connect to Exchange Online first'
                  }
               }
            }

            <# Fix for Get-AdminAuditLogConfig (#1045)
               Connect-IPPSSession imports a temporary PSSession module that breaks Get-AdminAuditLogConfig. This script
               block removes the broken function and re-imports the temporary PSSession module for EXO, which restores
               the working Get-AdminAuditLogConfig function.
            #>
            if ($securityComplianceConnected) {
               $ExchangeConnectionInformation = Get-ConnectionInformation
               if ($ExchangeConnectionInformation | Where-Object { $_.IsEopSession -eq $true -and $_.State -eq 'Connected' }) {
                  try {
                     # Remove the broken cmdlet and re-import the working EXO one.
                     Remove-Item -Path 'Function:\Get-AdminAuditLogConfig' -Force -ErrorAction SilentlyContinue
                     $ExchangeConnectionInformation | Where-Object { $_.IsEopSession -ne $true -and $_.State -eq 'Connected' } |
                     Select-Object -ExpandProperty ModuleName |
                     Import-Module -Function 'Get-AdminAuditLogConfig' > $null
                  } catch {
                     Write-Error "Failed to restore Get-AdminAuditLogConfig cmdlet: $($_.Exception.Message)"
                  }
               }
            }
         }
      }

      'Microsoft.Graph.Authentication' {
         if ($Service -contains 'Graph' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Graph'
            try {

               $scopes = Get-MtGraphScope -SendMail:$SendMail -SendTeamsMessage:$SendTeamsMessage `
                  -Privileged:$Privileged -IncludePreview:$IncludePreview

               $connectParams = @{
                  Scopes        = $scopes
                  NoWelcome     = $true
                  UseDeviceCode = $UseDeviceCode
                  Environment   = $Environment
               }

               if ($GraphClientId) {
                  $connectParams['ClientId'] = $GraphClientId
               }
               if ($TenantId) {
                  $connectParams['TenantId'] = $TenantId
               }
               if ($PSBoundParameters.ContainsKey('ClientTimeout')) {
                  $connectParams['ClientTimeout'] = $ClientTimeout
               }

               Write-Verbose "🦒 Connecting to Microsoft Graph with parameters:"
               Write-Verbose ($connectParams | ConvertTo-Json -Depth 5)
               try {
                  Connect-MgGraph @connectParams -ErrorVariable graphConnectError
               } finally {
                  # Connect-MgGraph errors are non-terminating unless $ErrorActionPreference is Stop.
                  # Check them for missing consent either way without changing how the error surfaces.
                  if ($graphConnectError) {
                     $null = Write-MtGraphConsentHelp -ErrorRecord $graphConnectError -GraphClientId $GraphClientId `
                        -TenantId $TenantId -Environment $Environment `
                        -SendMail:$SendMail -SendTeamsMessage:$SendTeamsMessage -Privileged:$Privileged -IncludePreview:$IncludePreview
                  }
               }

               $graphContext = Get-MgContext
               if ($graphConnectError -or -not $graphContext) {
                  $graphFailure = if ($graphConnectError) { Get-ErrorSummary $graphConnectError[0] } else { 'Not signed in' }
                  Add-ConnectionResult -Name 'Microsoft Graph' -Status 'Failed' -Details $graphFailure
               } else {
                  $graphAccount = if ($graphContext.Account) { $graphContext.Account } else { $graphContext.AppName }
                  Add-ConnectionResult -Name 'Microsoft Graph' -Status 'Connected' -Details $graphAccount
               }

               #ensure TenantId
               if (-not $TenantId) {
                  $TenantId = $graphContext.TenantId
               }

            } catch [Management.Automation.CommandNotFoundException] {
               Write-Verbose 'The Graph PowerShell module is not installed. For more information see https://learn.microsoft.com/powershell/microsoftgraph/installation'
               Add-ConnectionResult -Name 'Microsoft Graph' -Status 'Not installed' -Details 'Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
            } catch {
               Write-Verbose "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
               Add-ConnectionResult -Name 'Microsoft Graph' -Status 'Failed' -Details (Get-ErrorSummary $_)
            }
         }
      }

      'MicrosoftTeams' {
         if ($Service -contains 'Teams' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Teams'
            try {
               $teamsParams = @{ ErrorAction = 'Stop' }
               if ($UseDeviceCode) {
                  $teamsParams['UseDeviceAuthentication'] = $true
               } elseif ($TeamsEnvironmentName) {
                  $teamsParams['TeamsEnvironmentName'] = $TeamsEnvironmentName
               }
               $teamsConnection = Connect-MicrosoftTeams @teamsParams
               $teamsAccount = if ($teamsConnection.Account.Id) { $teamsConnection.Account.Id } elseif ($teamsConnection.Account) { "$($teamsConnection.Account)" }
               Add-ConnectionResult -Name 'Microsoft Teams' -Status 'Connected' -Details $teamsAccount
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Verbose 'The Teams PowerShell module is not installed. For more information see https://learn.microsoft.com/microsoftteams/teams-powershell-install'
               Add-ConnectionResult -Name 'Microsoft Teams' -Status 'Not installed' -Details 'Run: Install-Module MicrosoftTeams -Scope CurrentUser'
            } catch {
               Write-Verbose "Failed to connect to Microsoft Teams: $($_.Exception.Message)"
               Add-ConnectionResult -Name 'Microsoft Teams' -Status 'Failed' -Details (Get-ErrorSummary $_)
            }
         }
      }

      'PnP.PowerShell' {
         # SharePoint Online via PnP — must run AFTER Graph to avoid Microsoft.Graph.Core DLL conflict
         if ($Service -contains 'SharePointOnline' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to SharePoint Online via PnP'

            $resolvedSharePointClientId = $SharePointClientId

            if (-not $resolvedSharePointClientId) {
               Write-Verbose 'SharePoint Online connection skipped because -SharePointClientId was not provided.'
               Add-ConnectionResult -Name 'SharePoint Online' -Status 'Skipped' -Details '-SharePointClientId was not provided'
            } elseif (-not $SharePointAdminUrl -and $Service -notcontains 'Graph' -and $Service -notcontains 'All') {
               Write-Verbose "SharePoint admin URL auto-discovery requires a Microsoft Graph connection. Either include 'Graph' in -Service or supply -SharePointAdminUrl explicitly (e.g. https://contoso-admin.sharepoint.com)."
               Add-ConnectionResult -Name 'SharePoint Online' -Status 'Skipped' -Details 'Include Graph in -Service or pass -SharePointAdminUrl'
            } elseif ($SharePointCertificateThumbprint -and -not $TenantId) {
               Add-ConnectionResult -Name 'SharePoint Online' -Status 'Failed' -Details '-TenantId is required with -SharePointCertificateThumbprint'
            } elseif (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
               Write-Verbose 'The PnP.PowerShell module is not installed. For more information see https://pnp.github.io/powershell/articles/installation.html'
               Add-ConnectionResult -Name 'SharePoint Online' -Status 'Not installed' -Details 'Run: Install-Module PnP.PowerShell -Scope CurrentUser'
            } else {
               try {
                  # Use the provided admin URL or auto-discover from the tenant's initial domain
                  if ($SharePointAdminUrl) {
                     $spoAdminUrl = $SharePointAdminUrl
                     Write-Verbose "Using provided SharePoint admin URL: $spoAdminUrl"
                  } else {
                     $domains = Invoke-MtGraphRequest -RelativeUri "domains" -ApiVersion "v1.0"
                     $initialDomain = ($domains | Where-Object { $_.isInitial -eq $true }).id
                     $tenantPrefix = ($initialDomain -split '\.')[0]
                     $spoAdminUrl = "https://$tenantPrefix-admin.sharepoint.com"
                     Write-Verbose "Resolved SharePoint admin URL: $spoAdminUrl"
                  }

                  Import-Module PnP.PowerShell -ErrorAction Stop
                  $pnpParams = @{
                     Url      = $spoAdminUrl
                     ClientId = $resolvedSharePointClientId
                  }
                  if ($SharePointCertificateThumbprint) {
                     $pnpParams['Thumbprint'] = $SharePointCertificateThumbprint
                     $pnpParams['Tenant'] = $TenantId
                  } else {
                     if ($UseDeviceCode) {
                        $pnpParams['DeviceLogin'] = $true
                     } else {
                        $pnpParams['Interactive'] = $true
                     }
                     if ($TenantId) {
                        $pnpParams['Tenant'] = $TenantId
                     }
                  }
                  Connect-PnPOnline @pnpParams -ErrorAction Stop
                  Add-ConnectionResult -Name 'SharePoint Online' -Status 'Connected' -Details $spoAdminUrl
               } catch {
                  Write-Verbose "Failed to connect to SharePoint Online: $($_.Exception.Message)"
                  Add-ConnectionResult -Name 'SharePoint Online' -Status 'Failed' -Details (Get-ErrorSummary $_)
               }
            }
         }
      }
   }

   if ($Service -contains 'GitHub') {
      Write-Verbose 'Connecting to GitHub'
      $connectGitHubParams = @{}
      if (-not [string]::IsNullOrWhiteSpace($GitHubOrganization)) {
         $connectGitHubParams['Organization'] = $GitHubOrganization
      }
      try {
         # Connect-MtGitHub explains its own failures, so the summary only needs the outcome.
         Connect-MtGitHub @connectGitHubParams
         $gitHubConnection = $__MtSession.GitHubConnection
         if ($gitHubConnection.Connected) {
            Add-ConnectionResult -Name 'GitHub' -Status 'Connected' -Details $gitHubConnection.Organization
         } else {
            $gitHubFailure = if ($gitHubConnection.FailureReason) { "$($gitHubConnection.FailureReason), see the message above" } else { 'See the message above' }
            Add-ConnectionResult -Name 'GitHub' -Status 'Failed' -Details $gitHubFailure
         }
      } catch {
         Write-Verbose "Failed to connect to GitHub: $($_.Exception.Message)"
         Add-ConnectionResult -Name 'GitHub' -Status 'Failed' -Details (Get-ErrorSummary $_)
      }
   }

    # Active Directory connection validation is separate from OrderedImport because it has no module conflicts.
    if ($Service -contains 'ActiveDirectory') {
       Write-Verbose 'Connecting to Active Directory through the protocol-aware LDAP path'
       Add-Type -AssemblyName System.DirectoryServices.Protocols
       try {
          $connectAdParameters = @{
             AuthMode = $ActiveDirectoryAuthMode
             TlsMode  = $ActiveDirectoryTlsMode
          }

          foreach ($selectorName in 'ActiveDirectoryForest', 'ActiveDirectoryDomain', 'ActiveDirectoryServer', 'ActiveDirectoryCredential') {
             if ($PSBoundParameters.ContainsKey($selectorName)) {
                $connectAdParameters[$selectorName] = $PSBoundParameters[$selectorName]
             }
          }

          Connect-MtAdTarget @connectAdParameters
          Write-Verbose ("Active Directory protocol evidence: resolved target '{0}', domain '{1}', forest '{2}', auth '{3}', TLS '{4}'." -f `
                $__MtSession.ADConnection.ResolvedServer,
                $__MtSession.ADConnection.ResolvedDomain,
                $__MtSession.ADConnection.ResolvedForest,
                $__MtSession.ADConnection.AuthenticationMode,
                $__MtSession.ADConnection.TlsMode)
          Add-ConnectionResult -Name 'Active Directory' -Status 'Connected' -Details ("{0} ({1})" -f $__MtSession.ADConnection.ResolvedDomain, $__MtSession.ADConnection.ResolvedServer)
       } catch {
          Write-Verbose "Failed to connect to Active Directory: $($_.Exception.Message)"
          Add-ConnectionResult -Name 'Active Directory' -Status 'Failed' -Details (Get-ErrorSummary $_)
       }
    }

   Write-MtConnectionSummary -Summary $connectionSummary
} # end function Connect-Maester

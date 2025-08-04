function Connect-Maester {
   <#
.SYNOPSIS
   Helper method to connect to Microsoft Graph using Connect-MgGraph with the required permission scopes as well as other services such as Azure and Exchange Online.

.DESCRIPTION
   Use this cmdlet to connect to Microsoft Graph and the Microsoft 365 services that Maester can assess. It attempts to connect to all services by default: Microsoft Graph, Azure, Exchange Online, and Microsoft Teams.

   This command is completely optional if you are already connected to Microsoft Graph and other services using Connect-MgGraph with the required scopes.

   ```
   Connect-MgGraph -Scopes (Get-MtGraphScope)
   ```

.EXAMPLE
   Connect-Maester

   Connects to all Microsoft services that Maester is able to assess: Microsoft Graph, Azure, Exchange Online, Exchange Online Security & Compliance, and Microsoft Teams.

.EXAMPLE
   Connect-Maester -Service Graph,Teams

   Connects to Microsoft Graph and Microsoft Teams.

.EXAMPLE
   Connect-Maester -Service Azure,Graph

   Connects to Microsoft Graph and Azure.

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

   Connects to Microsoft Graph with additional privileged scopes such as **RoleEligibilitySchedule.ReadWrite.Directory** that are required for querying global admin roles in Privileged Identity Management.

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

      # If specified, the cmdlet will include the scopes for read write API endpoints. This is currently required for querying global admin roles in PIM.
      [switch] $Privileged,

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

      # The services to connect to such as Azure and EXO. Default is Graph.
      [ValidateSet('All', 'Azure', 'ExchangeOnline', 'Graph', 'SecurityCompliance', 'Teams')]
      [string[]]$Service = 'Graph',

      # The Tenant ID to connect to, if not specified the sign-in user's default tenant is used.
      [string]$TenantId,

      # The Client ID of the app to connect to for Graph. If not specified, the default Graph PowerShell CLI enterprise app will be used. Reference on how to create an enterprise app: https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0#use-delegated-access-with-a-custom-application-for-microsoft-graph-powershell
      [string]$GraphClientId
   )

   $__MtSession.Connections = $Service

   $OrderedImport = Get-ModuleImportOrder -Name @('Az.Accounts', 'ExchangeOnlineManagement', 'Microsoft.Graph.Authentication', 'MicrosoftTeams')
   switch ($OrderedImport.Name) {

      'Az.Accounts' {
         if ($Service -contains 'Azure' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Azure'
            try {
               if ($TenantId) {
                  Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment -Tenant $TenantId
               } else {
                  Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment
               }
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Host "`nThe Azure PowerShell module is not installed. Please install the module using the following command. For more information see https://learn.microsoft.com/powershell/azure/install-azure-powershell" -ForegroundColor Red
               Write-Host "`Install-Module Az.Accounts -Scope CurrentUser`n" -ForegroundColor Yellow
            }
         }
      }

      'ExchangeOnlineManagement' {
         $ExchangeModuleNotInstalledWarningShown = $false
         if ($Service -contains 'ExchangeOnline' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Exchange Online'
            try {
               if ($UseDeviceCode -and $PSVersionTable.PSEdition -eq 'Desktop') {
                  Write-Host 'The Exchange Online module in Windows PowerShell does not support device code flow authentication.' -ForegroundColor Red
                  Write-Host '💡Please use the Exchange Online module in PowerShell Core.' -ForegroundColor Yellow
               } elseif ( $UseDeviceCode ) {
                  Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ExchangeEnvironmentName $ExchangeEnvironmentName
               } else {
                  Connect-ExchangeOnline -ShowBanner:$false -ExchangeEnvironmentName $ExchangeEnvironmentName
               }
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Host "`nThe Exchange Online module is not installed. Please install the module using the following command.`nFor more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2" -ForegroundColor Red
               Write-Host "`nInstall-Module ExchangeOnlineManagement -Scope CurrentUser`n" -ForegroundColor Yellow
               $ExchangeModuleNotInstalledWarningShown = $true
            }
         }

         if ($Service -contains 'SecurityCompliance' -or $Service -contains 'All') {
            $Environments = @{
               'O365China'         = @{
                  ConnectionUri    = 'https://ps.compliance.protection.partner.outlook.cn/powershell-liveid'
                  AuthZEndpointUri = 'https://login.chinacloudapi.cn/common'
               }
               'O365GermanyCloud'  = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
               'O365Default'       = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
               'O365USGovGCCHigh'  = @{
                  ConnectionUri    = 'https://ps.compliance.protection.office365.us/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.us/common'
               }
               'O365USGovDoD'      = @{
                  ConnectionUri    = 'https://l5.ps.compliance.protection.office365.us/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.us/common'
               }
               Default             = @{
                  ConnectionUri    = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
                  AuthZEndpointUri = 'https://login.microsoftonline.com/common'
               }
            }
            Write-Verbose 'Connecting to Microsoft Security & Compliance PowerShell'
            if ($Service -notcontains 'ExchangeOnline' -and $Service -notcontains 'All') {
               Write-Host "`nThe Security & Compliance module is dependent on the Exchange Online module. Please include ExchangeOnline when specifying the services.`nFor more information see https://learn.microsoft.com/en-us/powershell/exchange/connect-to-scc-powershell" -ForegroundColor Red
            } else {
               if ($UseDeviceCode) {
                  Write-Host "`nThe Security & Compliance module does not support device code flow authentication." -ForegroundColor Red
               } else {
                  try {
                     Connect-IPPSSession -BypassMailboxAnchoring -ConnectionUri $Environments[$ExchangeEnvironmentName].ConnectionUri -AzureADAuthorizationEndpointUri $Environments[$ExchangeEnvironmentName].AuthZEndpointUri -ShowBanner:$false
                  } catch [Management.Automation.CommandNotFoundException] {
                     if (-not $ExchangeModuleNotInstalledWarningShown) {
                        Write-Host "`nThe Exchange Online module is not installed. Please install the module using the following command.`nFor more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2" -ForegroundColor Red
                        Write-Host "`nInstall-Module ExchangeOnlineManagement -Scope CurrentUser`n" -ForegroundColor Yellow
                     }
                  } catch {
                     $ExoUPN = Get-ConnectionInformation | Select-Object -ExpandProperty UserPrincipalName -First 1 -ErrorAction SilentlyContinue
                     if ($ExoUPN) {
                        Write-Host "`nAttempting to connect to the Security & Compliance PowerShell using UPN '$ExoUPN' derived from the ExchangeOnline connection." -ForegroundColor Yellow
                        Connect-IPPSSession -BypassMailboxAnchoring -UserPrincipalName $ExoUPN -ShowBanner:$false
                     } else {
                        Write-Host "`nFailed to connect to the Security & Compliance PowerShell. Please ensure you are connected to Exchange Online first." -ForegroundColor Red
                     }
                  }
               }
            }
         }
      }

      'Microsoft.Graph.Authentication' {
         if ($Service -contains 'Graph' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Graph'
            try {

               $scopes = Get-MtGraphScope -SendMail:$SendMail -SendTeamsMessage:$SendTeamsMessage -Privileged:$Privileged

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

               Write-Verbose "🦒 Connecting to Microsoft Graph with parameters:"
               Write-Verbose ($connectParams | ConvertTo-Json -Depth 5)
               Connect-MgGraph @connectParams

               #ensure TenantId
               if (-not $TenantId) {
                  $TenantId = (Get-MgContext).TenantId
               }

            } catch [Management.Automation.CommandNotFoundException] {
               Write-Host "`nThe Graph PowerShell module is not installed. Please install the module using the following command. For more information see https://learn.microsoft.com/powershell/microsoftgraph/installation" -ForegroundColor Red
               Write-Host "`Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`n" -ForegroundColor Yellow
            }
         }
      }

      'MicrosoftTeams' {
         if ($Service -contains 'Teams' -or $Service -contains 'All') {
            Write-Verbose 'Connecting to Microsoft Teams'
            try {
               if ($UseDeviceCode) {
                  Connect-MicrosoftTeams -UseDeviceAuthentication
               } elseif ($TeamsEnvironmentName) {
                  Connect-MicrosoftTeams -TeamsEnvironmentName $TeamsEnvironmentName > $null
               } else {
                  Connect-MicrosoftTeams > $null
               }
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Host "`nThe Teams PowerShell module is not installed. Please install the module using the following command. For more information see https://learn.microsoft.com/en-us/microsoftteams/teams-powershell-install" -ForegroundColor Red
               Write-Host "`Install-Module MicrosoftTeams -Scope CurrentUser`n" -ForegroundColor Yellow
            }
         }
      }
   } # end switch OrderedImport

} # end function Connect-Maester

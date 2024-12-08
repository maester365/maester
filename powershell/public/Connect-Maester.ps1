<#
.SYNOPSIS
   Helper method to connect to Microsoft Graph using Connect-MgGraph with the required permission scopes as well as other services such as Azure and Exchange Online.

.DESCRIPTION
   Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

   This command is completely optional if you are already connected to Microsoft Graph and other services using Connect-MgGraph with the required scopes.

   ```
   Connect-MgGraph -Scopes (Get-MtGraphScope)
   ```

.EXAMPLE
   Connect-Maester

   Connects to Microsoft Graph using Connect-MgGraph with the required scopes.

.EXAMPLE
   Connect-Maester -Service All

   Connects to Microsoft Graph, Azure, and Exchange Online.

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
   Connect-Maester -Environment Germany

   Connects to the Germany environment for Microsoft Graph.

.LINK
    https://maester.dev/docs/commands/Connect-Maester
#>
function Connect-Maester {
   [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
   [Alias("Connect-MtGraph", "Connect-MtMaester")]
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
      [ValidateSet("China", "Germany", "Global", "USGov", "USGovDoD")]
      [string]$Environment = "Global",

      # The Azure environment to connect to. Default is AzureCloud. Supported values include AzureChinaCloud, AzureCloud, AzureUSGovernment.
      [ValidateSet("AzureChinaCloud", "AzureCloud", "AzureUSGovernment")]
      [string]$AzureEnvironment = "AzureCloud",

      # The Exchange environment to connect to. Default is O365Default. Supported values include O365China, O365Default, O365GermanyCloud, O365USGovDoD, O365USGovGCCHigh.
      [ValidateSet("O365China", "O365Default", "O365GermanyCloud", "O365USGovDoD", "O365USGovGCCHigh")]
      [string]$ExchangeEnvironmentName = "O365Default",

      # The services to connect to such as Azure and EXO. Default is Graph.
      [ValidateSet("All", "Azure", "ExchangeOnline", "Graph", "SecurityCompliance")]
      [string[]]$Service = "Graph"
   )

   $__MtSession.Connections = $Service

   if ($Service -contains "Graph" -or $Service -contains "All") {
      Write-Verbose "Connecting to Microsoft Graph"
      try {
         Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail:$SendMail -SendTeamsMessage:$SendTeamsMessage -Privileged:$Privileged) -NoWelcome -UseDeviceCode:$UseDeviceCode -Environment $Environment
      } catch [Management.Automation.CommandNotFoundException] {
         Write-Host "`nThe Graph PowerShell module is not installed. Please install the module using the following command. For more information see https://learn.microsoft.com/powershell/microsoftgraph/installation" -ForegroundColor Red
         Write-Host "`Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`n" -ForegroundColor Yellow
      }
   }

   if ($Service -contains "Azure" -or $Service -contains "All") {
      Write-Verbose "Connecting to Microsoft Azure"
      try {
         Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment
      } catch [Management.Automation.CommandNotFoundException] {
         Write-Host "`nThe Azure PowerShell module is not installed. Please install the module using the following command. For more information see https://learn.microsoft.com/powershell/azure/install-azure-powershell" -ForegroundColor Red
         Write-Host "`Install-Module Az.Accounts -Scope CurrentUser`n" -ForegroundColor Yellow
      }
   }

   if ($Service -contains "ExchangeOnline" -or $Service -contains "All") {
      Write-Verbose "Connecting to Microsoft Exchage Online"
      try {
         if ( $UseDeviceCode -and $PSVersionTable.PSEdition -eq "Desktop" ) {
            Write-Host "The Exchange Online module in Windows PowerShell does not support device code flow authentication." -ForegroundColor Red
            Write-Host "💡Please use the Exchange Online module in PowerShell Core." -ForegroundColor Yellow
         } elseif ( $UseDeviceCode ) {
            Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ExchangeEnvironmentName $ExchangeEnvironmentName
         } else {
            Connect-ExchangeOnline -ShowBanner:$false -ExchangeEnvironmentName $ExchangeEnvironmentName
         }
      } catch [Management.Automation.CommandNotFoundException] {
         Write-Host "`nThe Exchange Online module is not installed. Please install the module using the following command.`nFor more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2" -ForegroundColor Red
         Write-Host "`nInstall-Module ExchangeOnlineManagement -Scope CurrentUser`n" -ForegroundColor Yellow
      }
   }

   if ($Service -contains "SecurityCompliance" -or $Service -contains "All") {
      $environments = @{
         O365China        = @{
            ConnectionUri    = "https://ps.compliance.protection.partner.outlook.cn/powershell-liveid"
            AuthZEndpointUri = "https://login.chinacloudapi.cn/common"
         }
         O365GermanyCloud = @{
            ConnectionUri    = "https://ps.compliance.protection.outlook.com/powershell-liveid/"
            AuthZEndpointUri = "https://login.microsoftonline.com/common"
         }
         O365Default      = @{
            ConnectionUri    = "https://ps.compliance.protection.outlook.com/powershell-liveid/"
            AuthZEndpointUri = "https://login.microsoftonline.com/common"
         }
         O365USGovGCCHigh = @{
            ConnectionUri    = "https://ps.compliance.protection.office365.us/powershell-liveid/"
            AuthZEndpointUri = "https://login.microsoftonline.us/common"
         }
         O365USGovDoD     = @{
            ConnectionUri    = "https://l5.ps.compliance.protection.office365.us/powershell-liveid/"
            AuthZEndpointUri = "https://login.microsoftonline.us/common"
         }
      }
      Write-Verbose "Connecting to Microsoft Security & Complaince PowerShell"
      if ($Service -notcontains "ExchangeOnline" -and $Service -notcontains "All") {
         Write-Host "`nThe Security & Complaince module is dependent on the Exchange Online module. Please include ExchangeOnline when specifying the services.`nFor more information see https://learn.microsoft.com/en-us/powershell/exchange/connect-to-scc-powershell" -ForegroundColor Red
      } else {
         if ($UseDeviceCode) {
            Write-Host "`nThe Security & Compliance module does not support device code flow authentication." -ForegroundColor Red
         } else {
            try {
               Connect-IPPSSession -BypassMailboxAnchoring -ConnectionUri $environments[$ExchangeEnvironmentName].ConnectionUri -AzureADAuthorizationEndpointUri $environments[$ExchangeEnvironmentName].AuthZEndpointUri
            } catch [Management.Automation.CommandNotFoundException] {
               Write-Host "`nThe Exchange Online module is not installed. Please install the module using the following command.`nFor more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2" -ForegroundColor Red
               Write-Host "`nInstall-Module ExchangeOnlineManagement -Scope CurrentUser`n" -ForegroundColor Yellow
            }
         }
      }
   }
}
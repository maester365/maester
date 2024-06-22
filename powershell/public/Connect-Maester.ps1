<#
.SYNOPSIS
   Helper method to connect to Microsoft Graph using Connect-MgGraph with the required scopes.

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
   Connect-Maester -Privileged

   Connects to Microsoft Graph with additional privileged scopes such as **RoleEligibilitySchedule.ReadWrite.Directory** that are required for querying global admin roles in Privileged Identity Management.

#>

Function Connect-Maester {
   [Alias("Connect-MtGraph", "Connect-MtMaester")]
   [CmdletBinding()]
   param(
      # If specified, the cmdlet will include the scope to send email (Mail.Send).
      [switch] $SendMail,

      # If specified, the cmdlet will include the scopes for read write API endpoints. This is currently required for querying global admin roles in PIM.
      [switch] $Privileged,

      # If specified, the cmdlet will use the device code flow to authenticate to Graph and Azure.
      # This will open a browser window to prompt for authentication and is useful for non-interactive sessions and on Windows when SSO is not desired.
      [switch] $UseDeviceCode,

      # The environment to connect to. Default is Global.
      [ValidateSet("China", "Germany", "Global", "USGov", "USGovDoD")]
      [string]$Environment = "Global",

      # The Azure environment to connect to. Default is AzureCloud.
      [ValidateSet("AzureChinaCloud", "AzureCloud", "AzureUSGovernment")]
      [string]$AzureEnvironment = "AzureCloud",

      # The Exchange environment to connect to. Default is O365Default.
      [ValidateSet("O365China", "O365Default", "O365GermanyCloud", "O365USGovDoD", "O365USGovGCCHigh")]
      [string]$ExchangeEnvironmentName = "O365Default",

      # The services to connect to such as Azure and EXO. Default is Graph.
      [ValidateSet("All", "Azure", "ExchangeOnline", "Graph")]
      [string[]]$Service = "Graph"
   )

   $__MtSession.Connections = $Service

   if ($Service -contains "Graph" -or $Service -contains "All") {
      Write-Verbose "Connecting to Microsoft Graph"
      try {
         Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail:$SendMail -Privileged:$Privileged) -NoWelcome -UseDeviceCode:$UseDeviceCode -Environment $Environment
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
         Write-Host "`Install-Module Az -Scope CurrentUser`n" -ForegroundColor Yellow
      }
   }

   if ($Service -contains "ExchangeOnline" -or $Service -contains "All") {
      Write-Verbose "Connecting to Microsoft Exchage Online"
      try {
         Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ExchangeEnvironmentName $ExchangeEnvironmentName
      } catch [Management.Automation.CommandNotFoundException] {
         Write-Host "`nThe Exchange Online module is not installed. Please install the module using the following command.`nFor more information see https://learn.microsoft.com/powershell/exchange/exchange-online-powershell-v2" -ForegroundColor Red
         Write-Host "`nInstall-Module ExchangeOnlineManagement -Scope CurrentUser`n" -ForegroundColor Yellow
      }
   }
}
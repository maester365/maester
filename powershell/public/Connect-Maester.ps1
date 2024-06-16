<#
 .Synopsis
    Helper method to connect to Microsoft Graph using Connect-MgGraph with the required scopes.

 .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

    This command is completely optional if you are already connected to Microsoft Graph using Connect-MgGraph with the required scopes.
    ```
    Connect-MgGraph -Scopes (Get-MtGraphScope)
    ```

 .Example
    Connect-Maester

 .Example
    Connect-Maester -Service All

 .Example
    Connect-Maester -Service Azure,Graph
#>

Function Connect-Maester {
   [Alias("Connect-MtGraph", "Connect-MtMaester")]
   [CmdletBinding()]
   param(
      # If specified, the cmdlet will include the scope to send email (Mail.Send).
      [switch] $SendMail,

      # If specified, the cmdlet will use the device code flow to authenticate.
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
      [ValidateSet("All","Azure","ExchageOnline","Graph")]
      [string[]]$Service = "Graph"
   )

   $__MtSession.Connections = $Service

   if($Service -contains "Graph" -or $Service -contains "All"){
      Write-Verbose "Connecting to Microsoft Graph"
      Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail:$SendMail) -NoWelcome -UseDeviceCode:$UseDeviceCode -Environment $Environment
   }

   if($Service -contains "Azure" -or $Service -contains "All"){
      Write-Verbose "Connecting to Microsoft Azure"
      Connect-AzAccount -SkipContextPopulation -UseDeviceAuthentication:$UseDeviceCode -Environment $AzureEnvironment
   }

   if($Service -contains "ExchageOnline" -or $Service -contains "All"){
      Write-Verbose "Connecting to Microsoft Exchage Online"

      Connect-ExchangeOnline -ShowBanner:$false -Device:$UseDeviceCode -ExchangeEnvironmentName $ExchangeEnvironmentName
   }
}
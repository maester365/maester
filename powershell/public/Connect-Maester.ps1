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
#>

Function Connect-Maester {
   [Alias("Connect-MtGraph", "Connect-MtMaester")]
   [CmdletBinding(DefaultParameterSetName="Graph")]
   param(
      # If specified, the cmdlet will include the scope to send email (Mail.Send).
      [switch] $SendMail,

      # If specified, the cmdlet will use the device code flow to authenticate.
      [switch] $UseDeviceCode,

      # If specified, the cmdlet will attempt to use the machine identity.
      [switch] $Identity,

      [Parameter(ParameterSetName="All")]
      [switch]$All,

      [Parameter(ParameterSetName="Graph")]
      [switch]$Graph,
      [Parameter(ParameterSetName="All")]
      [Parameter(ParameterSetName="Graph")]
      # The environment to connect to. Default is Global.
      [ValidateSet("China", "Germany", "Global", "USGov", "USGovDoD")]
      [string]$Environment = "Global",

      [Parameter(ParameterSetName="Azure")]
      [switch]$Azure,
      [Parameter(ParameterSetName="All")]
      [Parameter(ParameterSetName="Azure")]
      [ValidateSet("AzureChinaCloud", "AzureCloud", "AzureUSGovernment")]
      [string]$AzureEnvironment = "AzureCloud"
   )

   # Get all switch parameters that are differenct connections
   $params = $MyInvocation.MyCommand.Parameters.Values | Where-Object {`
      $_.ParameterSets.Keys -notcontains "All" -and`
      $_.ParameterSets.Keys -notcontains "__AllParameterSets" -and`
      $_.ParameterType.Name -eq "SwitchParameter"
   }
   if($All){
      Set-Variable -Name $params.Name -Value $true
   }

   # If no connection parameters are set use Graph
   $default = -not (Get-Variable -Name $params.Name | Where-Object {`
      $_.Value -eq $true
   })
   if($Graph -or $default){
      Write-Verbose "Connecting to Microsoft Graph"
      Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail:$SendMail) -NoWelcome -UseDeviceCode:$UseDeviceCode -Environment $Environment -Identity:$Identity
   }

   if($Azure){
      Write-Verbose "Connecting to Microsoft Azure"
      Connect-AzAccount -SkipContextPopulation -UseDeviceCode:$UseDeviceCode -Environment $Environment -Identity:$Identity
   }
}
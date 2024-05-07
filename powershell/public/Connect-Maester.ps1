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
   [CmdletBinding()]
   param(
      # If specified, the cmdlet will include the scope to send email (Mail.Send).
      [switch] $SendMail,

      # If specified, the cmdlet will use the device code flow to authenticate.
      [switch] $UseDeviceCode,

      # The environment to connect to. Default is Global.
      [ValidateSet("China", "Germany", "Global", "USGov", "USGovDoD")]
      [string]$Environment = "Global"
   )

   Write-Verbose "Connecting to Microsoft Graph"
   Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail:$SendMail) -NoWelcome -UseDeviceCode:$UseDeviceCode -Environment $Environment
}
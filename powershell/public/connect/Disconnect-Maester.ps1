function Disconnect-Maester {
   <#
    .Synopsis
    Disconnects the services connected through Connect-Maester.

    .Description
    Use this cmdlet to sign out of the services connected through Connect-Maester.
    It also clears Maester Active Directory and GitHub session state, and disconnects the services of Maester Pack connectors. Use
    Disconnect-MtGraph when you only want to disconnect Microsoft Graph.

    .Example
    Disconnect-MtGraph

    .Example
    Disconnect-Maester

    .Example
    Disconnect-MtMaester

    .LINK
    https://maester.dev/docs/commands/Disconnect-Maester
    #>
   [Alias("Disconnect-MtMaester", "Disconnect-MtGraph")]
   [CmdletBinding()]
   param()

   if ($__MtSession.Connections -contains "Graph" -or $__MtSession.Connections -contains "All") {
      Write-Verbose -Message "Disconnecting from Microsoft Graph."
      Disconnect-MgGraph
   }

   if ($__MtSession.Connections -contains "Azure" -or $__MtSession.Connections -contains "Dataverse" -or $__MtSession.Connections -contains "All") {
      Write-Verbose -Message "Disconnecting from Microsoft Azure."
      try {
         Disconnect-AzAccount -ErrorAction Stop | Out-Null
      } catch {
         Write-Verbose "Disconnect-AzAccount encountered an error: $($_.Exception.Message)"
      }
   }

   if ($__MtSession.Connections -contains "ExchangeOnline" -or $__MtSession.Connections -contains "SecurityCompliance" -or $__MtSession.Connections -contains "All") {
      Write-Verbose -Message "Disconnecting from Microsoft Exchange Online."
      Disconnect-ExchangeOnline
   }
   if ($__MtSession.Connections -contains "SharePointOnline" -or $__MtSession.Connections -contains "All") {
      Write-Verbose -Message "Disconnecting from SharePoint Online (PnP)."
      try {
         Disconnect-PnPOnline -ErrorAction Stop
      } catch {
         Write-Verbose "Disconnect-PnPOnline encountered an error: $($_.Exception.Message)"
      }
      $__MtSession.SpoCache = @{}
   }

   if ($__MtSession.Connections -contains "Teams" -or $__MtSession.Connections -contains "All") {
      Write-Verbose -Message "Disconnecting from Microsoft Teams."
      Disconnect-MicrosoftTeams
   }

   if ($MyInvocation.InvocationName -notmatch '(^|\\)Disconnect-MtGraph$') {
      if ($null -ne $__MtSession.ADConnection) {
          Write-Verbose -Message "Clearing Active Directory connection data."
          $__MtSession.ADConnection = $null
          $__MtSession.ADCredential = $null
          Clear-MtADCache
      }

      Write-Verbose -Message "Disconnecting from GitHub."
      Disconnect-MtGitHub

      # Maester Pack connectors: their Disconnect function, then the state Maester kept for them.
      foreach ($packService in @($(if ($__MtSession.PackConnections) { $__MtSession.PackConnections.Keys }))) {
         Write-Verbose -Message "Disconnecting from $packService."
         try {
            $null = Invoke-MtPackConnector -Service $packService -Function Disconnect
         } catch {
            Write-Verbose "The connector of $packService failed to disconnect: $($_.Exception.Message)"
         }
      }
      $__MtSession.PackConnections = @{}
   }
}

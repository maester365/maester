function Disconnect-Maester {
    <#
    .Synopsis
    Helper method to sign out of the current Microsoft Graph session. Alternate for Disconnect-MgGraph.

    .Description
    Use this cmdlet to sign out of the current Microsoft Graph session.

    This cmdlet is a helper method for running the following command.
    ```
    Disconnect-MgGraph
    ```

    When invoked as Disconnect-Maester or Disconnect-MtMaester, also clears any active GitHub
    REST session (token, connection metadata, per-session cache). The Disconnect-MtGraph alias
    keeps its narrow Graph-only semantic and does NOT clear GitHub state.

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

   if($__MtSession.Connections -contains "Graph" -or $__MtSession.Connections -contains "All"){
      Write-Verbose -Message "Disconnecting from Microsoft Graph."
      Disconnect-MgGraph
   }

   if($__MtSession.Connections -contains "Azure" -or $__MtSession.Connections -contains "Dataverse" -or $__MtSession.Connections -contains "All"){
      Write-Verbose -Message "Disconnecting from Microsoft Azure."
      try {
         Disconnect-AzAccount -ErrorAction Stop | Out-Null
      } catch {
         Write-Verbose "Disconnect-AzAccount encountered an error: $($_.Exception.Message)"
      }
   }

   if($__MtSession.Connections -contains "ExchangeOnline" -or $__MtSession.Connections -contains "SecurityCompliance" -or $__MtSession.Connections -contains "All"){
      Write-Verbose -Message "Disconnecting from Microsoft Exchange Online."
      Disconnect-ExchangeOnline
   }
   if($__MtSession.Connections -contains "Teams" -or $__MtSession.Connections -contains "All"){
      Write-Verbose -Message "Disconnecting from Microsoft Teams."
      Disconnect-MicrosoftTeams
   }

   $invokedAs = $MyInvocation.InvocationName
   if ($invokedAs -iin @('Disconnect-Maester','Disconnect-MtMaester')) {
      Disconnect-MtGitHub
   }
}

<#
 .Synopsis
    Helper method to sign out of the current Microsoft Graph session. Alternate for Disconnect-MgGraph.

 .Description
    Use this cmdlet to sign out of the current Microsoft Graph session.

    This cmdlet is a helper method for running the following command.
    ```
    Disconnnect-MgGraph
    ```

 .Example
    Disconnect-MtGraph

 .Example
    Disconnect-Maester

 .Example
    Disconnect-MtMaester

#>

Function Disconnect-MtGraph {
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Disconnecting from Microsoft Graph."
    Disconnect-MgGraph
 }
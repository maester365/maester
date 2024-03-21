<#
 .Synopsis
    Helper method to connect to Microsoft Graph using Connect-MgGraph with the required scopes.

 .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

    This cmdlet is a helper method for running the following command.
    ```
    Connect-MgGraph -Scopes (Get-MtGraphScopes)
    ```

 .Example
    Connect-MtGraph
#>

Function Connect-MtGraph {
   Connect-MgGraph -Scopes (Get-MtGraphScopes) -NoWelcome
}
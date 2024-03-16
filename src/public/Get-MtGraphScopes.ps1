<#
 .Synopsis
    Returns the list of Graph scopes required to run Maester.

 .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScopes)
#>

Function Get-MtGraphScopes {

    return @(
        'Policy.Read.All'
        'Directory.Read.All'
        'Policy.ReadWrite.ConditionalAccess'
    )
}
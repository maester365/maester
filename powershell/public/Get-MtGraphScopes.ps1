<#
 .Synopsis
    Returns the list of Graph scopes required to run Maester.

 .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

 .Example
    Connect-MgGraph -Scopes (Get-MtGraphScopes)
#>

Function Get-MtGraphScopes {

    # Any changes made to these permission scopes should be reflected in the documentation.
    # /maester/website/docs/sections/permissions.md
    return @(
        'Policy.Read.All'
        'Directory.Read.All'
    )
}
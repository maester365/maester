function Test-MtModuleImported {
    <#
    .SYNOPSIS
    Returns $true when a module is imported in this session.

    .DESCRIPTION
    Test-MtConnection uses it for services whose connection only exists inside a session (Exchange Online,
    Security & Compliance, Teams, SharePoint Online): when the module is not imported there can be no
    connection, and calling one of its commands to find out would only make PowerShell auto-load the module.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Name
    )
    [bool](Get-Module -Name $Name)
}

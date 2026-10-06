function Test-MtCheckAZDO1008 {
    <#
    .SYNOPSIS
    Request access to Azure DevOps by e-mail notifications to administrators.

    .DESCRIPTION
    Runs the shared check Test-AzdoAllowRequestAccessToken.
    #>
    [MaesterTest(
        Id = 'AZDO.1008',
        Title = 'Request access to Azure DevOps by e-mail notifications to administrators.',
        Severity = 'Medium',
        Category = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://go.microsoft.com/fwlink/?linkid=2113172'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoAllowRequestAccessToken
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
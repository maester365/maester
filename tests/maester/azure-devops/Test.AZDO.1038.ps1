function Test-MtCheckAZDO1038 {
    <#
    .SYNOPSIS
    (Organization) Disallow extensions from accessing resources on the local network.

    .DESCRIPTION
    Runs the shared check Test-AzdoAllowExtensionsLocalNetworkAccess.
    #>
    [MaesterTest(
        Id = 'AZDO.1038',
        Title = '(Organization) Disallow extensions from accessing resources on the local network.',
        Severity = 'Medium',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/marketplace/allow-extensions-local-network?view=azure-devops'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoAllowExtensionsLocalNetworkAccess
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}

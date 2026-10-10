function Test-MtCheckAZDO1003 {
    <#
    .SYNOPSIS
    Restrict public projects.

    .DESCRIPTION
    Runs the shared check Test-AzdoPublicProject.
    #>
    [MaesterTest(
        Id = 'AZDO.1003',
        Title = 'Restrict public projects.',
        Product = 'azure-devops',
        Severity = 'High',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://aka.ms/vsts-anon-access'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoPublicProject
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}

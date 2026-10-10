function Test-MtCheckAZDO1020 {
    <#
    .SYNOPSIS
    Creation of classic build pipelines.

    .DESCRIPTION
    Runs the shared check Test-AzdoOrganizationCreationClassicBuildPipeline.
    #>
    [MaesterTest(
        Id = 'AZDO.1020',
        Title = 'Creation of classic build pipelines.',
        Product = 'azure-devops',
        Severity = 'Medium',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoOrganizationCreationClassicBuildPipeline
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}

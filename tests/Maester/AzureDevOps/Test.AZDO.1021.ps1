function Test-MtCheckAZDO1021 {
    <#
    .SYNOPSIS
    Creation of classic release pipelines.

    .DESCRIPTION
    Runs the shared check Test-AzdoOrganizationCreationClassicReleasePipeline.
    #>
    [MaesterTest(
        Id = 'AZDO.1021',
        Title = 'Creation of classic release pipelines.',
        Severity = 'Medium',
        Category = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoOrganizationCreationClassicReleasePipeline
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
function Test-MtCheckAZDO1019 {
    <#
    .SYNOPSIS
    Stage chooser.

    .DESCRIPTION
    Runs the shared check Test-AzdoOrganizationStageChooser.
    #>
    [MaesterTest(
        Id = 'AZDO.1019',
        Title = 'Stage chooser.',
        Product = 'azure-devops',
        Feature = 'pipelines',
        Area = 'engineering-systems',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/pipelines/security/overview?view=azure-devops'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoOrganizationStageChooser
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}

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
        Feature = 'security-policies',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1213.003', 'T1593.003'),
        Control = ('nist-800-53-r5:AC-22', 'nist-800-53-r5:AC-3'),
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

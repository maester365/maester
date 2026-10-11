function Test-MtCheckAZDO1007 {
    <#
    .SYNOPSIS
    Team and project administrator are allowed to invite new users.

    .DESCRIPTION
    Runs the shared check Test-AzdoAllowTeamAdminsInvitationsAccessToken.
    #>
    [MaesterTest(
        Id = 'AZDO.1007',
        Title = 'Team and project administrator are allowed to invite new users.',
        Product = 'azure-devops',
        Feature = 'users-and-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1136.003',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://aka.ms/azure-devops-invitations-policy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoAllowTeamAdminsInvitationsAccessToken
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}

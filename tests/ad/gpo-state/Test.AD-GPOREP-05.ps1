function Test-MtAdGpoNoEnterpriseDcCount {
    <#
    .SYNOPSIS
    Checks that evaluated GPOs include Enterprise Domain Controllers permissions.
    .DESCRIPTION
    Passes when the principal is present on all evaluated GPOs, fails when absent,
    and reports unreadable permissions as unknown rather than missing.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-05', Title = 'GPOs should include Enterprise Domain Controllers permissions',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return Test-MtAdGpoPermission -PermissionProperties HasEnterpriseDomainControllers -ExpectedValue $true -FindingLabel 'GPOs without Enterprise Domain Controllers' -PassMessage 'No evaluated GPO lacks Enterprise Domain Controllers permissions.' -FailureMessage 'lack Enterprise Domain Controllers permissions; review and restore intended access.'
}

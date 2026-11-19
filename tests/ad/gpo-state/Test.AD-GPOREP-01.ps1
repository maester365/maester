function Test-MtAdGpoNoPermissionsCount {
    <#
    .SYNOPSIS
    Checks that every evaluated GPO has permission entries.
    .DESCRIPTION
    Fails on an empty permission list and reports unreadable descriptors separately.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-01', Title = 'No GPO should have an empty permissions list',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return Test-MtAdGpoPermission -PermissionProperties PermissionsPresent -ExpectedValue $true -FindingLabel 'GPOs with empty permissions' -PassMessage 'Every evaluated GPO has permission entries.' -FailureMessage 'have empty permission lists; restore intended GPO permissions.'
}

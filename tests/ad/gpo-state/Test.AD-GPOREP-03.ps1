function Test-MtAdGpoNoAuthenticatedUsersCount {
    <#
    .SYNOPSIS
    Checks that evaluated GPOs include Authenticated Users permissions.

    .DESCRIPTION
    Fails when Authenticated Users is absent; unknown permissions require review.
    Verify intentional security filtering before changing the ACL.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOREP-03'

    Fails when an evaluated GPO lacks Authenticated Users permissions.

    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-03
    #>
    [MaesterTest(
        Id                 = 'AD-GPOREP-03',
        Title              = 'GPOs should include Authenticated Users permissions',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'access-control',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return Test-MtAdGpoPermission -PermissionProperties HasAuthenticatedUsers -ExpectedValue $true -FindingLabel 'GPOs without Authenticated Users' -PassMessage 'No evaluated GPO lacks Authenticated Users permissions.' -FailureMessage 'lack Authenticated Users permissions; review intended security filtering before changing GPO permissions.'
}

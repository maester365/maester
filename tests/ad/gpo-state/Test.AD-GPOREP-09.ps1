function Test-MtAdGpoInheritedPermissionsCount {
    <#
    .SYNOPSIS
    Checks for inherited GPO permissions.

    .DESCRIPTION
    Fails when a GPO inherits permission entries. Reports unreadable descriptors
    separately; verify intended delegation before changing inheritance.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOREP-09'

    Fails when an evaluated GPO inherits permission entries.

    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-09
    #>
    [MaesterTest(
        Id                 = 'AD-GPOREP-09',
        Title              = 'GPOs should not inherit permission entries',
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
    return Test-MtAdGpoPermission -PermissionProperties HasInheritedPermissions -ExpectedValue $false -FindingLabel 'GPOs with inherited permissions' -PassMessage 'No evaluated GPO has inherited permission entries.' -FailureMessage 'have inherited permission entries; review delegation and define intended GPO permissions explicitly where appropriate.'
}

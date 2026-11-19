function Test-MtAdGpoNoDomainComputersCount {
    <#
    .SYNOPSIS
    Checks that GPO permissions include Domain Computers or Authenticated Users.
    .DESCRIPTION
    Fails only when both principals are absent. One known-present principal proves
    the condition; absence of one with the other unknown remains inconclusive.
    This principal-presence check does not calculate effective read access.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-06', Title = 'GPOs should include Domain Computers or Authenticated Users permissions',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Low', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return Test-MtAdGpoPermission -PermissionProperties HasDomainComputers, HasAuthenticatedUsers -ExpectedValue $true -FindingLabel 'GPOs with neither Domain Computers nor Authenticated Users' -PassMessage 'Every evaluated GPO includes Domain Computers or Authenticated Users. A missing Domain Computers entry alone is not a failure.' -FailureMessage 'include neither Domain Computers nor Authenticated Users; review permissions required for computer policy retrieval (MS16-072).'
}

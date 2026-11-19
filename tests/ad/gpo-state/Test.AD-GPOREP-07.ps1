function Test-MtAdGpoDenyAceCount {
    <#
    .SYNOPSIS
    Checks for GPOs with deny access entries.
    .DESCRIPTION
    Fails when a deny entry is found. Lists findings and unreadable permissions;
    review intentional restrictions before removing any entry.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-07', Title = 'GPOs should not have deny access entries',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Platform = 'Windows', Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return Test-MtAdGpoPermission -PermissionProperties HasDenyAce -ExpectedValue $false -FindingLabel 'GPOs with deny entries' -PassMessage 'No evaluated GPO has a deny access entry.' -FailureMessage 'have deny access entries; review their scope and remove unintended restrictions.'
}

function Test-MtAccessPackageDriftRoleAssignableGroup {
    <#
    .SYNOPSIS
    Checks that the members of governed role-assignable groups come from access package assignments.

    .DESCRIPTION
    Runs the shared check Test-MtAccessPackageDrift -Scope RoleAssignableGroup. Access package drift (Microsoft Entra ID
    Governance > Access Guardian, Microsoft Graph beta accessDriftSummary) compares the members of governed role-assignable groups
    with the access package assignments that should grant them. The check fails when one has unauthorized or missing access,
    passes when role-assignable groups are governed and none has drift, and is skipped when no role-assignable group is a resource of an
    entitlement management catalog. Members of role-assignable groups can be assigned Microsoft Entra roles, so unauthorized access is privileged access.

    Learn more:
    https://learn.microsoft.com/entra/id-governance/entitlement-management-reports#view-access-package-drift

    .EXAMPLE
    Test-MtAccessPackageDriftRoleAssignableGroup

    .LINK
    https://maester.dev/docs/tests/MT.1256
    #>
    [MaesterTest(
        Id = 'MT.1256',
        Title = 'Members of governed role-assignable groups come from access package assignments.',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'privileged-access',
        ResourceType = 'Group',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1098.003',
        Control = ('nist-800-53-r5:AC-2', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        License = 'Entra_Identity_Governance',
        Permission = 'Graph:Scope:EntitlementManagement.Read.All',
        Lifecycle = 'Preview',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Also fail when an access package assignment is missing its expected group membership.
        # Set to $false to fail on unauthorized access only and list missing access for review.
        [bool] $IncludeMissingAccess = $true,

        # Object IDs of governed role-assignable groups whose drift this check ignores.
        [string[]] $ExcludedResourceId,

        # Maximum number of role-assignable groups listed in the result; the others are counted.
        [ValidateRange(1, 1000)]
        [int] $MaxResources = 50
    )

    Test-MtAccessPackageDrift -Scope RoleAssignableGroup -IncludeMissingAccess $IncludeMissingAccess -ExcludedResourceId $ExcludedResourceId -MaxResources $MaxResources
}

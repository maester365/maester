function Test-MtAccessPackageDriftGroup {
    <#
    .SYNOPSIS
    Checks that the members of governed groups come from access package assignments.

    .DESCRIPTION
    Runs the shared check Test-MtAccessPackageDrift -Scope Group. Access package drift (Microsoft Entra ID
    Governance > Access Guardian, Microsoft Graph beta accessDriftSummary) compares the members of governed groups that are not role-assignable
    with the access package assignments that should grant them. The check fails when one has unauthorized or missing access,
    passes when groups are governed and none has drift, and is skipped when no group that is not role-assignable is a resource of an
    entitlement management catalog. Role-assignable groups are checked by MT.1256.

    Learn more:
    https://learn.microsoft.com/entra/id-governance/entitlement-management-reports#view-access-package-drift

    .EXAMPLE
    Test-MtAccessPackageDriftGroup

    .LINK
    https://maester.dev/docs/tests/MT.1255
    #>
    [MaesterTest(
        Id = 'MT.1255',
        Title = 'Members of governed groups come from access package assignments.',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'identity-lifecycle',
        ResourceType = 'Group',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1098',
        Control = 'nist-800-53-r5:AC-2',
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

        # Object IDs of governed groups whose drift this check ignores.
        [string[]] $ExcludedResourceId,

        # Maximum number of groups listed in the result; the others are counted.
        [ValidateRange(1, 1000)]
        [int] $MaxResources = 50
    )

    Test-MtAccessPackageDrift -Scope Group -IncludeMissingAccess $IncludeMissingAccess -ExcludedResourceId $ExcludedResourceId -MaxResources $MaxResources
}

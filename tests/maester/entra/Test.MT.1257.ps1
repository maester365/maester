function Test-MtAccessPackageDriftApplication {
    <#
    .SYNOPSIS
    Checks that the app role assignments of governed applications come from access package assignments.

    .DESCRIPTION
    Runs the shared check Test-MtAccessPackageDrift -Scope Application. Access package drift (Microsoft Entra ID
    Governance > Access Guardian, Microsoft Graph beta accessDriftSummary) compares the app role assignments of governed enterprise applications
    with the access package assignments that should grant them. The check fails when one has unauthorized or missing access,
    passes when applications are governed and none has drift, and is skipped when no enterprise application is a resource of an
    entitlement management catalog.

    Learn more:
    https://learn.microsoft.com/entra/id-governance/entitlement-management-reports#view-access-package-drift

    .EXAMPLE
    Test-MtAccessPackageDriftApplication

    .LINK
    https://maester.dev/docs/tests/MT.1257
    #>
    [MaesterTest(
        Id = 'MT.1257',
        Title = 'App role assignments of governed applications come from access package assignments.',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'identity-lifecycle',
        ResourceType = 'ServicePrincipal',
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
        # Also fail when an access package assignment is missing its expected app role assignment.
        # Set to $false to fail on unauthorized access only and list missing access for review.
        [bool] $IncludeMissingAccess = $true,

        # Object IDs of governed applications whose drift this check ignores.
        [string[]] $ExcludedResourceId,

        # Maximum number of applications listed in the result; the others are counted.
        [ValidateRange(1, 1000)]
        [int] $MaxResources = 50
    )

    Test-MtAccessPackageDrift -Scope Application -IncludeMissingAccess $IncludeMissingAccess -ExcludedResourceId $ExcludedResourceId -MaxResources $MaxResources
}

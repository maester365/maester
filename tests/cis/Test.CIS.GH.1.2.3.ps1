function Test-MtCisGitHubRepositoryDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.3: Ensure repository deletion is limited to specific users.

    .DESCRIPTION
    Assesses the CIS owner or repository-administrator branch using typed live
    evidence and users configured as trusted and qualified in GitHubDeletionPolicy.
    Missing approvals or unresolved restrictive alternatives require investigation.

    .EXAMPLE
    Test-MtCisGitHubRepositoryDeletionLimited -MaximumOrganizationOwners 3

    Checks the connected organization against the configured approval roster.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubRepositoryDeletionLimited
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.2.3',
        Title = 'Ensure repository deletion is limited to specific users',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1485', 'T1070'),
        Control = ('cis-github:1.2.3', 'nist-800-53-r5:AC-6'),
        Service = 'GitHub',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum live organization owners when member repository deletion is disabled; a Maester policy choice, not a CIS numeric requirement.
        [ValidateRange(1, 2147483647)]
        [int] $MaximumOrganizationOwners = 3
    )

    return Test-MtCisGitHubDeletion -Kind Repository -MaximumOrganizationOwners $MaximumOrganizationOwners
}

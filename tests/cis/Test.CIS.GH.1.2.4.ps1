function Test-MtCisGitHubIssueDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.4: Ensure issue deletion is limited to specific users.

    .DESCRIPTION
    Assesses the CIS owner or repository-administrator branch using typed live
    evidence and users configured as trusted and qualified in GitHubDeletionPolicy.
    Missing approvals or unresolved restrictive alternatives require investigation.

    .EXAMPLE
    Test-MtCisGitHubIssueDeletionLimited -MaximumOrganizationOwners 3

    Checks the connected organization against the configured approval roster.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubIssueDeletionLimited
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.2.4',
        Title = 'Ensure issue deletion is limited to specific users',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1070', 'T1485'),
        Control = ('cis-github:1.2.4', 'nist-800-53-r5:AC-6'),
        Service = 'GitHub',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum live organization owners when member issue deletion is disabled; a Maester policy choice, not a CIS numeric requirement.
        [ValidateRange(1, 2147483647)]
        [int] $MaximumOrganizationOwners = 3
    )

    return Test-MtCisGitHubDeletion -Kind Issue -MaximumOrganizationOwners $MaximumOrganizationOwners
}

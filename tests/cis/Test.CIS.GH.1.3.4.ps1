function Test-MtCisGitHubContributorMfaRequired {
    <#
    .SYNOPSIS
    CIS.GH.1.3.4: Ensure Multi-Factor Authentication (MFA) is required for contributors of new code.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.3.4 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Organization two-factor enforcement reduces the risk that stolen passwords allow attackers to use outside collaborators' cloud accounts to change code.

    .EXAMPLE
    Test-MtCisGitHubContributorMfaRequired

    Assesses CIS.GH.1.3.4 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.3.4
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.3.4',
        Title = 'Ensure Multi-Factor Authentication (MFA) is required for contributors of new code',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'High',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = 'cis-github:1.3.4',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisGitHubMemberMfaRequired
}

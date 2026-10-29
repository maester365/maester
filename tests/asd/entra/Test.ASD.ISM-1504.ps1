function Test-MtAsdMfaAllUsers {
    <#
    .SYNOPSIS
    Checks that an enabled Conditional Access policy requires multi-factor authentication for all users on all resources.

    .DESCRIPTION
    ISM-1504 (Essential Eight, Multi-factor authentication, Maturity Level One) asks that multi-factor
    authentication is used to authenticate human users to their organisation's online services that process,
    store or communicate their organisation's sensitive data. ASD defines the factors that count but not how the
    policy is built, so this is what CIS.M365.5.2.2.2 checks, and this test runs that check
    (Test-MtCisMfaForEveryUser).

    .EXAMPLE
    Test-MtAsdMfaAllUsers

    Returns true when a policy requires MFA for all users on all resources.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1504
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'All users is the name of the Conditional Access scope.')]
    [MaesterTest(
        Id = 'ASD.ISM-1504',
        Title = 'Multi-factor authentication is used to authenticate human users to their organisation''s online services.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110'),
        Control = ('essential-eight:ISM-1504', 'nist-800-53-r5:IA-2(2)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisMfaForEveryUser
}

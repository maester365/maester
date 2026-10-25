function Test-MtAsdMfaAllUsers {
    <#
    .SYNOPSIS
    Checks that an enabled Conditional Access policy requires multi-factor authentication for all users on all cloud apps.

    .DESCRIPTION
    ISM-1504 (Essential Eight, Multi-factor authentication, Maturity Level One) asks that multi-factor
    authentication is used to authenticate users to the organisation's online services that process, store or
    communicate its sensitive data. ISM-0974 (Maturity Level Two) extends it to unprivileged users of systems.

    The check passes when at least one enabled Conditional Access policy targets all users and all cloud apps
    and grants access only with the built-in MFA control or an authentication strength that satisfies MFA.
    Policies that only act on Identity Protection risk do not count.

    .EXAMPLE
    Test-MtAsdMfaAllUsers

    Returns true when a policy requires MFA for all users on all cloud apps.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1504
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'All users is the name of the Conditional Access scope.')]
    [MaesterTest(
        Id = 'ASD.ISM-1504',
        Title = 'Multi-factor authentication is used to authenticate users of the organisation''s online services.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110'),
        Control = ('essential-eight:ISM-1504', 'essential-eight:ISM-0974', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtAsdMfaPolicy -Scope AllUsers)
    $testResult = $policies.Count -gt 0

    if ($testResult) {
        $testResultMarkdown = "Well done. These Conditional Access policies require multi-factor authentication for all users on all cloud apps:`n`n%TestResult%"
    } else {
        $testResultMarkdown = 'No enabled Conditional Access policy requires multi-factor authentication for all users on all cloud apps.'
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjects $policies -GraphObjectType ConditionalAccess
    return $testResult
}

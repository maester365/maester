function Test-MtAsdMfaPrivilegedUsers {
    <#
    .SYNOPSIS
    Checks that an enabled Conditional Access policy requires multi-factor authentication for every privileged directory role.

    .DESCRIPTION
    ISM-1173 (Essential Eight, Multi-factor authentication, Maturity Level Two) asks that multi-factor
    authentication is used to authenticate privileged users of systems.

    The check passes when at least one enabled Conditional Access policy targets all cloud apps, covers each of
    the fourteen highly privileged directory roles listed in the guide (by including all users, or by including
    each role without excluding it) and grants access only with the built-in MFA control or an authentication
    strength that satisfies MFA. Other roles that Microsoft Entra marks as privileged are not checked.

    .EXAMPLE
    Test-MtAsdMfaPrivilegedUsers

    Returns true when a policy requires MFA for every privileged role on all cloud apps.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1173
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Privileged users is the subject of the ISM control.')]
    [MaesterTest(
        Id = 'ASD.ISM-1173',
        Title = 'Multi-factor authentication is used to authenticate privileged users.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1110'),
        Control = ('essential-eight:ISM-1173', 'nist-800-53-r5:IA-2(1)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtAsdMfaPolicy -Scope PrivilegedRoles)
    $testResult = $policies.Count -gt 0

    if ($testResult) {
        $testResultMarkdown = "Well done. These Conditional Access policies require multi-factor authentication for every privileged directory role on all cloud apps:`n`n%TestResult%"
    } else {
        $testResultMarkdown = 'No enabled Conditional Access policy requires multi-factor authentication for every privileged directory role on all cloud apps.'
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjects $policies -GraphObjectType ConditionalAccess
    return $testResult
}

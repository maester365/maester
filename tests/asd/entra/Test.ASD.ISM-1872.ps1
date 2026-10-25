function Test-MtAsdPhishingResistantMfa {
    <#
    .SYNOPSIS
    Checks that an enabled Conditional Access policy requires phishing-resistant MFA for all users on all cloud apps.

    .DESCRIPTION
    ISM-1872 (Essential Eight, Multi-factor authentication, Maturity Level Two) asks that the multi-factor
    authentication used to authenticate users of online services is phishing-resistant.

    The check passes when at least one enabled Conditional Access policy targets all users and all cloud apps
    and grants access only with the built-in Phishing-resistant MFA authentication strength, or a custom
    strength limited to Windows Hello for Business, passkeys (FIDO2) and certificate-based multi-factor
    authentication.

    .EXAMPLE
    Test-MtAsdPhishingResistantMfa

    Returns true when a policy requires a phishing-resistant authentication strength for all users.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1872
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1872',
        Title = 'Multi-factor authentication used for authenticating users of online services is phishing-resistant.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'High',
        ImplementationCost = 'High',
        Mitre = 'T1566.002',
        Control = ('essential-eight:ISM-1872', 'cisa-scuba:MS.AAD.3.1'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtAsdMfaPolicy -Scope AllUsers -PhishingResistant)
    $testResult = $policies.Count -gt 0

    if ($testResult) {
        $testResultMarkdown = "Well done. These Conditional Access policies require phishing-resistant MFA for all users on all cloud apps:`n`n%TestResult%"
    } else {
        $testResultMarkdown = 'No enabled Conditional Access policy requires a phishing-resistant authentication strength for all users on all cloud apps.'
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjects $policies -GraphObjectType ConditionalAccess
    return $testResult
}

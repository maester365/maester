function Test-MtAsdPhishingResistantMfa {
    <#
    .SYNOPSIS
    Checks that an enabled Conditional Access policy requires phishing-resistant MFA for all users on all resources.

    .DESCRIPTION
    ISM-1872 (Essential Eight, Multi-factor authentication, Maturity Level Two) asks that the multi-factor
    authentication used to authenticate human users of online services is phishing-resistant. ASD's assessment
    guide applies it to unprivileged and privileged users alike, and the ASD Blueprint for Secure Cloud meets it
    with one policy for all users and all resources that requires the Phishing-resistant MFA authentication
    strength. That is what CISA.MS.AAD.3.1 checks, and this test runs that check (Test-MtCisaPhishResistant).

    .EXAMPLE
    Test-MtAsdPhishingResistantMfa

    Returns true when a policy requires a phishing-resistant authentication strength for all users.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1872
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1872',
        Title = 'Multi-factor authentication used for authenticating human users of online services is phishing-resistant.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'High',
        ImplementationCost = 'High',
        Mitre = 'T1566.002',
        Control = 'essential-eight:ISM-1872',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPhishResistant
}

function Test-MtDisaEntraMfa {
    <#
    .SYNOPSIS
    Checks that a Conditional Access policy requires multifactor authentication for all users.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270233, CAT I): Microsoft Entra ID must be configured to use multifactor authentication (MFA).

    This test runs CIS.M365.5.2.2.2 (Test-MtCisMfaForEveryUser). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraMfa

    Returns the result of CIS.M365.5.2.2.2 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270233
    #>
    [MaesterTest(
        Id = 'DISA.V-270233',
        Title = 'Microsoft Entra ID must be configured to use multifactor authentication (MFA).',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110'),
        Control = 'disa-stig-entra-id:V-270233',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisMfaForEveryUser
}

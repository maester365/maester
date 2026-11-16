function Test-MtDisaEntraBannedPasswordList {
    <#
    .SYNOPSIS
    Checks that the custom banned password list is enforced and filled in.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270475, CAT II): Microsoft Entra ID must, for password-based authentication, verify when users create or update passwords that the passwords are not found on the list of commonly used, expected, or compromised passwords.

    This test runs CIS.M365.5.2.3.2 (Test-MtCisCustomBannedPasswordList). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraBannedPasswordList

    Returns the result of CIS.M365.5.2.3.2 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270475
    #>
    [MaesterTest(
        Id = 'DISA.V-270475',
        Title = 'Microsoft Entra ID must, for password-based authentication, verify when users create or update passwords that the passwords are not found on the list of commonly used, expected, or compromised passwords.',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110.003',
        Control = 'disa-stig-entra-id:V-270475',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisCustomBannedPasswordList
}

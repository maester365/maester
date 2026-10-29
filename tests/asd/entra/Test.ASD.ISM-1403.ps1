function Test-MtAsdSmartLockoutThreshold {
    <#
    .SYNOPSIS
    Checks that the Microsoft Entra smart lockout threshold is five failed sign-ins or fewer.

    .DESCRIPTION
    ISM-1403 (Guidelines for system access, User account lockouts) asks that user accounts, except for break
    glass accounts, are protected by fixed or risk-based lockout mechanisms aligned to a maximum of five failed
    logon attempts. This control is not part of the Essential Eight maturity model. The ASD Blueprint for Secure
    Cloud sets the smart lockout threshold to 5.

    CIS.M365.5.2.3.8 reads the same setting and allows up to 10, so this test runs that check
    (Test-MtCisSmartLockoutThreshold) with ASD's maximum. The Microsoft default of 10 fails.

    .EXAMPLE
    Test-MtAsdSmartLockoutThreshold

    Returns true when the smart lockout threshold is 5 or fewer.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1403
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1403',
        Title = 'User accounts are protected by lockout mechanisms aligned to a maximum of five failed logon attempts.',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1110.001', 'T1110.003'),
        Control = ('ism:ISM-1403', 'nist-800-53-r5:AC-7'),
        Service = 'Graph',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most failed sign-ins allowed before an account is locked. ASD sets five; CIS allows ten.
        [ValidateRange(1, 50)]
        [int] $MaximumLockoutThreshold = 5
    )

    return Test-MtCisSmartLockoutThreshold -MaximumLockoutThreshold $MaximumLockoutThreshold
}

function Test-MtDisaEntraLockout {
    <#
    .SYNOPSIS
    Checks that smart lockout locks an account after three failed sign-ins for at least 15 minutes.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270208, CAT II): Microsoft Entra ID must enforce the limit of three consecutive invalid logon attempts by a user during a 15-minute time period.

    This test runs CIS.M365.5.2.3.8 (Test-MtCisSmartLockoutThreshold). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraLockout

    Returns the result of CIS.M365.5.2.3.8 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270208
    #>
    [MaesterTest(
        Id = 'DISA.V-270208',
        Title = 'Microsoft Entra ID must enforce the limit of three consecutive invalid logon attempts by a user during a 15-minute time period.',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1110.001', 'T1110.003'),
        Control = 'disa-stig-entra-id:V-270208',
        Service = 'Graph',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most failed sign-ins allowed before an account is locked. DISA sets three.
        [ValidateRange(1, 50)]
        [int] $MaximumLockoutThreshold = 3,

        # Shortest lockout duration, in seconds. DISA sets 900 (15 minutes).
        [ValidateRange(0, 86400)]
        [int] $MinimumLockoutDurationSeconds = 900
    )

    return Test-MtCisSmartLockoutThreshold -MaximumLockoutThreshold $MaximumLockoutThreshold -MinimumLockoutDurationSeconds $MinimumLockoutDurationSeconds
}

function Test-MtDisaIntuneDesktopInactiveAccount {
    <#
    .SYNOPSIS
    Checks that no enabled user account has been inactive for 35 days or more.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop STIG (V-267309, CAT II): Microsoft Intune service must automatically disable accounts after a 35-day period of account inactivity.

    This test runs DISA.V-270204 (Test-MtDisaInactiveAccount). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneDesktopInactiveAccount

    Returns the result of DISA.V-270204 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-267309
    #>
    [MaesterTest(
        Id = 'DISA.V-267309',
        Title = 'Microsoft Intune service must automatically disable accounts after a 35-day period of account inactivity.',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = 'disa-stig-intune-desktop:V-267309',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Days without a sign-in after which an account must be disabled. DISA sets 35.
        [ValidateRange(1, 365)]
        [int] $MaximumInactiveDays = 35
    )

    return Test-MtDisaInactiveAccount -MaximumInactiveDays $MaximumInactiveDays
}

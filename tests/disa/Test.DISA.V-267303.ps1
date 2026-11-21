function Test-MtDisaIntuneDesktopIdleSessionTimeout {
    <#
    .SYNOPSIS
    Checks that the Microsoft 365 idle session timeout is 15 minutes or less.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop STIG (V-267303, CAT II): Microsoft Intune service must initiate a session lock after a 15-minute period of inactivity.

    This test runs DISA.V-273867 (Test-MtDisaIdleSessionTimeout). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneDesktopIdleSessionTimeout

    Returns the result of DISA.V-273867 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-267303
    #>
    [MaesterTest(
        Id = 'DISA.V-267303',
        Title = 'Microsoft Intune service must initiate a session lock after a 15-minute period of inactivity.',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1550.004',
        Control = 'disa-stig-intune-desktop:V-267303',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest idle session timeout that is allowed, in minutes. DISA sets 15.
        [ValidateRange(1, 1440)]
        [int] $MaximumIdleTimeoutMinutes = 15
    )

    return Test-MtDisaIdleSessionTimeout -MaximumIdleTimeoutMinutes $MaximumIdleTimeoutMinutes
}

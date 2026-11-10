function Test-MtDisaEntraIdleSessionTimeout {
    <#
    .SYNOPSIS
    Checks that idle sessions are signed out after 15 minutes of inactivity or less.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270200, CAT II): Microsoft Entra ID must initiate a session lock after a 15-minute period of inactivity.

    This test runs DISA.V-273867 (Test-MtDisaIdleSessionTimeout). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraIdleSessionTimeout

    Returns the result of DISA.V-273867 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270200
    #>
    [MaesterTest(
        Id = 'DISA.V-270200',
        Title = 'Microsoft Entra ID must initiate a session lock after a 15-minute period of inactivity.',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1550.004',
        Control = 'disa-stig-entra-id:V-270200',
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

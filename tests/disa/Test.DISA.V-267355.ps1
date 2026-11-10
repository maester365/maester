function Test-MtDisaIntuneDesktopPasswordLifetime {
    <#
    .SYNOPSIS
    Checks that passwords expire after 60 days or less on every verified, managed domain.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop STIG (V-267355, CAT II): Microsoft Intune service must enforce a 60-day maximum password lifetime restriction.

    This test runs DISA.V-270239 (Test-MtDisaPasswordLifetime). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneDesktopPasswordLifetime

    Returns the result of DISA.V-270239 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-267355
    #>
    [MaesterTest(
        Id = 'DISA.V-267355',
        Title = 'Microsoft Intune service must enforce a 60-day maximum password lifetime restriction.',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Domain',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = 'disa-stig-intune-desktop:V-267355',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest password lifetime that is allowed, in days. This STIG sets 60.
        [ValidateRange(1, 730)]
        [int] $MaximumPasswordAgeDays = 60
    )

    return Test-MtDisaPasswordLifetime -MaximumPasswordAgeDays $MaximumPasswordAgeDays
}

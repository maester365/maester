function Test-MtDisaIntuneDesktopMfa {
    <#
    .SYNOPSIS
    Checks that a Conditional Access policy requires multifactor authentication for all users.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop STIG (V-267341, CAT II): Microsoft Intune service must be configured to use multifactor authentication for network access to privileged and nonprivileged accounts.

    This test runs CIS.M365.5.2.2.2 (Test-MtCisMfaForEveryUser). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneDesktopMfa

    Returns the result of CIS.M365.5.2.2.2 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-267341
    #>
    [MaesterTest(
        Id = 'DISA.V-267341',
        Title = 'Microsoft Intune service must be configured to use multifactor authentication for network access to privileged and nonprivileged accounts.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110'),
        Control = 'disa-stig-intune-desktop:V-267341',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisMfaForEveryUser
}

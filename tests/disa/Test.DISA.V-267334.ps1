function Test-MtDisaIntuneDesktopLogExport {
    <#
    .SYNOPSIS
    Checks that an Intune diagnostic setting sends the audit logs to another store.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop STIG (V-267334, CAT II): Microsoft Intune service must be configured to transfer Intune logs to another server for storage, analysis, and reporting at least every seven days.

    This test runs MT.1100 (Test-MtIntuneDiagnosticSettings). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneDesktopLogExport

    Returns the result of MT.1100 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-267334
    #>
    [MaesterTest(
        Id = 'DISA.V-267334',
        Title = 'Microsoft Intune service must be configured to transfer Intune logs to another server for storage, analysis, and reporting at least every seven days.',
        Product = 'intune',
        Feature = 'tenant-administration',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1685.002',
        Control = 'disa-stig-intune-desktop:V-267334',
        Service = 'Azure',
        License = 'INTUNE_A',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtIntuneDiagnosticSettings
}

function Test-MtDisaIntuneLogExport {
    <#
    .SYNOPSIS
    Checks that an Intune diagnostic setting sends the audit logs to another store.

    .DESCRIPTION
    DISA Microsoft Intune MDM Service Desktop and Mobile STIG (V-273868, CAT II): Microsoft Intune service must be configured to transfer Intune logs to another server for storage, analysis, and reporting at least every seven days.

    This test runs MT.1100 (Test-MtIntuneDiagnosticSettings). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaIntuneLogExport

    Returns the result of MT.1100 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-273868
    #>
    [MaesterTest(
        Id = 'DISA.V-273868',
        Title = 'Microsoft Intune service must be configured to transfer Intune logs to another server for storage, analysis, and reporting at least every seven days.',
        Product = 'intune',
        Feature = 'tenant-administration',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1685.002',
        Control = 'disa-stig-intune-mdm:V-273868',
        Service = 'Azure',
        License = 'INTUNE_A',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtIntuneDiagnosticSettings
}

function Test-MtCisDevicesWithoutCompliancePolicyMarked {
    <#
    .SYNOPSIS
        Checks if devices without a compliance policy assigned are marked "not compliant".

    .DESCRIPTION
        Devices without a compliance policy assigned should be marked "not compliant".
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (4.1, L1)

        The benchmark's audit reads deviceManagement/settings and verifies that secureByDefault is True.
        MT.1054 checks the same setting, so this test runs that check (Test-MtDeviceComplianceSettings).

    .EXAMPLE
        Test-MtCisDevicesWithoutCompliancePolicyMarked

        Returns true if devices without a compliance policy assigned are marked "not compliant".

    .LINK
        https://maester.dev/docs/tests/CIS.M365.4.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.4.1',
        Title = 'Ensure devices without a compliance policy are marked ''not compliant''',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:4.1', 'nist-800-53-r5:AC-19', 'nist-800-53-r5:CM-6'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'oed-metzb',
        Contributor = ('Mynster9361', 'Korthal-Maiyn')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtDeviceComplianceSettings
}

function Test-MtCheckMT1022 {
    <#
    .SYNOPSIS
    All users utilizing a P1 license should be licensed.

    .DESCRIPTION
    Runs the shared check Test-MtCaLicenseUtilization with -License P1.
    #>
    [MaesterTest(
        Id = 'MT.1022',
        Title = 'All users utilizing a P1 license should be licensed.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'f-bader',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $licenseReport = Test-MtCaLicenseUtilization -License 'P1'
    if ($null -eq $licenseReport) { return $null }
    # Passed when no more users utilize P1 features than are entitled to a P1 license.
    return (-not ($licenseReport.TotalLicensesUtilized -gt $licenseReport.EntitledLicenseCount))
}

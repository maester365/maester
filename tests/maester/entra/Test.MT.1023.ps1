function Test-MtCheckMT1023 {
    <#
    .SYNOPSIS
    All users utilizing a P2 license should be licensed.

    .DESCRIPTION
    Runs the shared check Test-MtCaLicenseUtilization with -License P2.
    #>
    [MaesterTest(
        Id = 'MT.1023',
        Title = 'All users utilizing a P2 license should be licensed.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
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

    $licenseReport = Test-MtCaLicenseUtilization -License 'P2'
    if ($null -eq $licenseReport) { return $null }
    # Passed when no more users utilize P2 features than are entitled to a P2 license.
    return (-not ($licenseReport.TotalLicensesUtilized -gt $licenseReport.EntitledLicenseCount))
}

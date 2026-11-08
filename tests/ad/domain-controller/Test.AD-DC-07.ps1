function Test-MtAdDcOperatingSystemCount {
    <#
    .SYNOPSIS
    Checks the forest DC operating-system baseline and lists each classified DC.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DC-07',
        Title = 'Forest DC operating systems meet the minimum supported release',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'High',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Oldest acceptable Windows Server release for every forest domain controller.
        [ValidateSet(2016, 2019, 2022, 2025)]
        [int] $MinimumSupportedRelease = 2022
    )

    $state = Get-MtADDomainState -Categories @('DomainControllers')
    $controllers = @($state.DomainControllers)
    if ($controllers.Count -eq 0) { throw 'Forest DC inventory unavailable.' }
    $rows = @('| Domain controller | Directory OS | Version | Classified release | Baseline |', '| --- | --- | --- | --- | --- |')
    $releases = @()
    foreach ($dc in $controllers) {
        $release = Get-MtAdDomainControllerRelease -Controller $dc
        $releases += $release
        $rows += "| $($dc.DnsHostName) | $($dc.OperatingSystem) | $($dc.OperatingSystemVersion) | $release | $(if ($release -ge $MinimumSupportedRelease) { 'Meets' } else { 'Below' }) |"
    }
    $old = @($releases | Where-Object { $_ -lt $MinimumSupportedRelease })
    $ok = $old.Count -eq 0
    $distinctReleases = @($releases | Sort-Object -Unique)
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. All inventoried forest DCs meet the minimum OS release.' } else { 'Upgrade DCs below the minimum supported OS release.' }) Baseline: Server $MinimumSupportedRelease; forest DC count: $($controllers.Count); distinct releases: $($distinctReleases.Count).`n`n$($rows -join "`n")`n`nDirectory OS inventory does not measure patch installation or support contracts."
    return $ok
}

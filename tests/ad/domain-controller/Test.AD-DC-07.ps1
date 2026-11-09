function Test-MtAdDcOperatingSystemCount {
    <#
    .SYNOPSIS
    Checks the connected domain's DC operating-system baseline and lists each classified DC.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DC-07
    Assess connected-domain DC operating systems against the minimum supported release.
    .LINK
    https://maester.dev/docs/tests/AD-DC-07
    #>
    [MaesterTest(
        Id = 'AD-DC-07',
        Title = 'Connected-domain DC operating systems meet the minimum supported release',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'High',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Oldest acceptable Windows Server release for connected-domain controllers.
        [ValidateSet(2016, 2019, 2022, 2025)]
        [int] $MinimumSupportedRelease = 2022
    )

    $state = Get-MtADDomainState -Categories @('Domain', 'DomainControllers')
    $controllers = @(Get-MtAdDomainControllersInScope -State $state)
    if ($controllers.Count -eq 0) { throw 'Connected-domain DC inventory unavailable.' }
    $excludedCount = @($state.DomainControllers).Count - $controllers.Count
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
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'Domain assessed' = $state.Domain.DnsRoot
        'Minimum Windows Server release' = $MinimumSupportedRelease
        'Assessed DCs' = $controllers.Count
        'Other-domain DCs excluded' = $excludedCount
        'Distinct OS releases' = $distinctReleases.Count
    })
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. All inventoried connected-domain DCs meet the minimum OS release.' } else { 'Upgrade connected-domain DCs below the minimum supported OS release.' })`n`n$metrics`n`n$($rows -join "`n")`n`nOther domains require separate assessment. Directory OS inventory does not measure patch installation or support contracts."
    return $ok
}

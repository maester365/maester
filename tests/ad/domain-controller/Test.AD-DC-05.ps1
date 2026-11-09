function Test-MtAdDcAllFsmoRolesCount {
    <#
    .SYNOPSIS
    Checks recommended FSMO placement and lists each recorded role owner.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DC-05
    Assess FSMO owner placement against the recommended role placement.
    .LINK
    https://maester.dev/docs/tests/AD-DC-05
    #>
    [MaesterTest(
        Id = 'AD-DC-05',
        Title = 'FSMO owners meet recommended role placement',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest', 'Domain', 'DomainControllers', 'OptionalFeatures')
    $placement = Get-MtAdFsmoPlacement -State $state
    $ok = $placement.Issues.Count -eq 0
    $rows = @('| FSMO role | Owner NTDS Settings DN |', '| --- | --- |')
    foreach ($role in $placement.Owners.Keys) {
        $rows += "| $role | $($placement.Owners[$role]) |"
    }
    $holderCount = @($placement.Owners.Values | Select-Object -Unique).Count
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'Recorded roles' = $placement.Owners.Count
        'Distinct owner DNs' = $holderCount
        'Placement issues' = $placement.Issues.Count
    })
    $findings = if ($ok) { '' } else { "`n`n#### Placement findings`n`n" + (@($placement.Issues | ForEach-Object { '- ' + (Format-MtAdSiteInventoryValue $_) }) -join "`n") }
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. ✅ FSMO owners meet recommended placement.' } else { '⚠️ Review FSMO role placement.' })$findings`n`n$metrics`n`n$($rows -join "`n")`n`nRole owner distribution does not establish physical redundancy or DC reachability."
    return $ok
}

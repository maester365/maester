function Test-MtAdDcAllFsmoRolesCount {
    <#
    .SYNOPSIS
    Checks recommended FSMO placement and lists each recorded role owner.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
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
    $details = "Recorded roles: $($placement.Owners.Count); distinct owner DNs: $holderCount.`n`n$($rows -join "`n")"
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. FSMO owners meet recommended placement.' } else { 'Review FSMO role placement: ' + ($placement.Issues -join '; ') })`n`n$details`n`nRole owner distribution does not establish physical redundancy or DC reachability."
    return $ok
}

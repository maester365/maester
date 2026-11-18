function Test-MtAdNetbiosNameStandardCompliance {
    <#
    .SYNOPSIS
    Checks forest domain NetBIOS names and lists any invalid names.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DOM-07
    Assess forest domain NetBIOS names for valid syntax.
    .LINK
    https://maester.dev/docs/tests/AD-DOM-07
    #>
    [MaesterTest(
        Id = 'AD-DOM-07',
        Title = 'Forest domain NetBIOS names have valid syntax',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest')
    $findings = @(Get-MtAdDomainNameFindings -Forest $state.Forest -Kind Netbios)
    $ok = $findings.Count -eq 0
    $rows = @('| Forest domain DN | NetBIOS name | Syntax |', '| --- | --- | --- |')
    foreach ($partition in @($state.Forest.DomainPartitions)) {
        $invalid = @($findings | Where-Object { $_ -ceq "$($partition.NetBIOSName) ($($partition.DistinguishedName))" }).Count -gt 0
        $rows += "| $($partition.DistinguishedName) | $($partition.NetBIOSName) | $(if ($invalid) { 'Invalid' } else { 'Valid' }) |"
    }
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. Forest domain NetBIOS names pass syntax validation.' } else { 'Review invalid forest domain NetBIOS names and plan a supported migration.' }) Forest domains: $($state.Forest.DomainPartitions.Count); invalid: $($findings.Count).`n`n$($rows -join "`n")"
    return $ok
}

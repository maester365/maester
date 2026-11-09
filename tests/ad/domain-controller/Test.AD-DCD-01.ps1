function Test-MtAdDcNonStandardLdapPortCount {
    <#
    .SYNOPSIS
    Reports LDAP and LDAPS advertised-port metadata without implying live connectivity.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DCD-01
    Review advertised LDAP and LDAPS port metadata manually, not live connectivity.
    .LINK
    https://maester.dev/docs/tests/AD-DCD-01
    #>
    [MaesterTest(
        Id = 'AD-DCD-01',
        Title = 'LDAP and LDAPS port metadata for review',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('DomainControllers')
    if ($null -eq $state.DomainControllers) { throw 'DC inventory unavailable.' }
    $controllers = @($state.DomainControllers)
    $rows = @('| DC | LDAP advertised | LDAPS advertised | Port evidence |', '| --- | --- | --- | --- |')
    foreach ($dc in $controllers) {
        $ldap = if ($null -eq $dc.LdapPort) { 'Unknown' } else { [string]$dc.LdapPort }
        $ldaps = if ($null -eq $dc.SslPort) { 'Unknown' } else { [string]$dc.SslPort }
        $evidence = if ($dc.PortEvidence) { [string]$dc.PortEvidence } else { 'Not measured' }
        $rows += "| $($dc.DnsHostName) | $ldap | $ldaps | $evidence |"
    }
    $ldapKnown = @($controllers | Where-Object { $null -ne $_.LdapPort })
    $ldapsKnown = @($controllers | Where-Object { $null -ne $_.SslPort })
    $ldapNonstandard = @($ldapKnown | Where-Object { $_.LdapPort -ne 389 })
    $ldapsNonstandard = @($ldapsKnown | Where-Object { $_.SslPort -ne 636 })
    $counts = @(
        '| Protocol | Standard port | Known metadata | Unknown metadata | Nonstandard metadata |'
        '| --- | --- | --- | --- | --- |'
        "| LDAP | 389 | $($ldapKnown.Count) | $($controllers.Count - $ldapKnown.Count) | $($ldapNonstandard.Count) |"
        "| LDAPS | 636 | $($ldapsKnown.Count) | $($controllers.Count - $ldapsKnown.Count) | $($ldapsNonstandard.Count) |"
    )
    Add-MtTestResultDetail -Result "Review LDAP and LDAPS port metadata.`n`n$($counts -join "`n")`n`n$($rows -join "`n")`n`nAdvertised metadata does not prove listening ports, TLS certificate validity or network reachability." -Investigate
}

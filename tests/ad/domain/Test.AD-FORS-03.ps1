function Test-MtAdSpnSuffixesCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-FORS-03
    Review the forest SPN suffix inventory manually.
    .LINK
    https://maester.dev/docs/tests/AD-FORS-03
    #>
    [MaesterTest(
        Id = 'AD-FORS-03',
        Title = 'SPN suffix inventory for review',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest')
    if (-not $state.Forest -or $null -eq $state.Forest.SPNSuffixes) { throw 'Forest SPN suffixes not collected.' }
    $suffixes = @($state.Forest.SPNSuffixes)
    $rows = @('| Configured SPN suffix |', '| --- |')
    foreach ($suffix in $suffixes) { $rows += '| {0} |' -f (Format-MtAdSiteInventoryValue $suffix) }
    if ($suffixes.Count -eq 0) { $rows += '| None configured |' }
    Add-MtTestResultDetail -Result "Review registered SPN namespaces. This is not a count of SPNs or their owners.`n`n| Metric | Value |`n| --- | --- |`n| Configured SPN suffix count | $($suffixes.Count) |`n`n$($rows -join "`n")" -Investigate
}

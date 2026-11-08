function Test-MtAdOuStaleCount {
    <#
    .SYNOPSIS
    OU modification age inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory ou modification age inventory.
    #>
    [MaesterTest(
        Id = 'AD-OU-03',
        Title = 'OU modification age inventory',
        Product = 'ad',
        Feature = 'organizational-units',
        Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:organizationalUnit:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum calendar years since an OU's last modification before it is listed.
        [ValidateRange(1, 100)]
        [int] $MaximumAgeYears = 5
    )

    $ous = @(Get-MtAdOrganizationalUnitOverview -State (Get-MtADDomainState -Categories @('OrganizationalUnits')))
    $cutoff = (Get-Date).AddYears(-$MaximumAgeYears)
    $rows = @('| OU | Last modified | Distinguished name |', '| --- | --- | --- |')
    $old = 0
    foreach ($ou in $ous) {
        $value = if ($null -ne $ou.Modified) { $ou.Modified } elseif ($null -ne $ou.whenChanged) { $ou.whenChanged } elseif ($null -ne $ou.modifyTimeStamp) { $ou.modifyTimeStamp } else { $null }
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { throw "OU '$($ou.DistinguishedName)' has no modification date." }
        $date = [datetime]::MinValue
        if (-not [datetime]::TryParse([string]$value, [ref]$date)) { throw "OU '$($ou.DistinguishedName)' has an invalid modification date." }
        if ($date -lt $cutoff) {
            $old++
            $rows += '| {0} | {1} | {2} |' -f (Format-MtAdSiteInventoryValue $ou.Name), $date.ToString('yyyy-MM-dd'), (Format-MtAdSiteInventoryValue $ou.DistinguishedName)
        }
    }
    Add-MtTestResultDetail -Result "Review $old OU(s) not modified in $MaximumAgeYears calendar year(s) out of $($ous.Count). Modification age is not a measure of use or deactivation.`n`n$($rows -join "`n")" -Investigate
    return $true
}

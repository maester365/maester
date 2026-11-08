function Get-MtAdDomainControllerRelease {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Controller)

    if ($Controller.CollectionError) { throw "DC metadata incomplete for $($Controller.Name): $($Controller.CollectionError)" }
    $name = [string]$Controller.OperatingSystem
    $version = [string]$Controller.OperatingSystemVersion
    $byName = if ($name -match '(?i)Windows\s+(?:Server\s+)?(2025|2022|2019|2016|2012|2008|2003|2000)\b') { [int]$Matches[1] } else { $null }
    $byBuild = if ($version -match '(?:^|\D)(26100|20348|17763|14393|9600|9200|7601|7600|6003|6002|6001|6000|3790|2195)(?:\D|$)') {
        switch ($Matches[1]) {
            '26100' { 2025 }; '20348' { 2022 }; '17763' { 2019 }; '14393' { 2016 }
            { $_ -in '9600', '9200' } { 2012 }
            { $_ -in '7601', '7600', '6003', '6002', '6001', '6000' } { 2008 }
            '3790' { 2003 }; '2195' { 2000 }
        }
    } else { $null }
    if ($null -ne $byName -and $null -ne $byBuild -and $byName -ne $byBuild) {
        throw "Conflicting OS metadata for $($Controller.Name): $name / $version."
    }
    $release = if ($null -ne $byBuild) { $byBuild } else { $byName }
    if ($null -eq $release) { throw "Unclassified DC OS for $($Controller.Name): $name / $version." }
    return $release
}

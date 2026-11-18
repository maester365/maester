function Get-MtAdFunctionalLevelAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [ValidateSet('Domain', 'Forest')] [string] $Scope
    )

    $controllers = @($State.DomainControllers)
    if ($controllers.Count -eq 0 -or $null -eq $State.$Scope) {
        throw "$Scope functional level cannot be assessed without the directory object and complete DC inventory."
    }
    foreach ($dc in $controllers) {
        if ($dc.CollectionError) { throw "DC metadata incomplete for $($dc.Name): $($dc.CollectionError)" }
    }
    $releases = @($controllers | ForEach-Object { Get-MtAdDomainControllerRelease -Controller $_ })
    for ($i = 0; $i -lt $controllers.Count; $i++) {
        $supported = $controllers[$i].SupportedLevelValue
        $expected = switch ($releases[$i]) {
            2025 { @(10) }; { $_ -in 2016, 2019, 2022 } { @(7) }
            2012 { @(5, 6) }; 2008 { @(3, 4) }; 2003 { @(2) }; 2000 { @(0) }
        }
        if ($null -eq $supported -or [string]$supported -notmatch '^(0|2|3|4|5|6|7|10)$' -or [int]$supported -notin $expected) {
            throw "Missing or inconsistent supported functional level for DC $($controllers[$i].Name)."
        }
    }
    $raw = if ($Scope -eq 'Domain') { $State.Domain.DomainLevelValue } else { $State.Forest.ForestLevelValue }
    if ($null -eq $raw -or [string]$raw -notmatch '^(0|[1-9][0-9]*)$') {
        throw "$Scope msDS-Behavior-Version is missing or invalid; the display mode is not authoritative."
    }
    $level = [int]$raw
    if ($level -notin @(0, 1, 2, 3, 4, 5, 6, 7, 10)) { throw "Unknown $Scope functional level $level." }
    $target = ($controllers | Measure-Object -Property SupportedLevelValue -Minimum).Minimum
    return [pscustomobject]@{ Current = $level; Target = $target; Releases = $releases }
}

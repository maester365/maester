function Get-MtMeasureSetting {
    <#
    .SYNOPSIS
    Returns the Measures section of a run config: whether measures are read, and the thresholds it changes.

    .DESCRIPTION
    Measures.Enabled (default true) turns the measures of the defender's path off, and
    Measures.MinimumShare.<key> changes the threshold of a measure, a whole number from 1 to 100
    (docs/proposals/defenders-path.md, section 8). Resolve-MtRunConfig has already rejected values out of range.

    Returns an object with Enabled (bool) and MinimumShare (a hashtable of measure key to threshold).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The resolved run config, or $null.
        [Parameter()] [AllowNull()] [object] $RunConfig
    )

    $enabled = $true
    $minimum = @{}
    $section = if ($RunConfig -and $RunConfig.PSObject.Properties['Measures']) { $RunConfig.Measures } else { $null }
    if ($section) {
        if ($section.PSObject.Properties['Enabled'] -and $null -ne $section.Enabled) { $enabled = [bool]$section.Enabled }
        $shares = if ($section.PSObject.Properties['MinimumShare']) { $section.MinimumShare } else { $null }
        if ($shares -is [System.Collections.IDictionary]) {
            foreach ($key in $shares.Keys) { if ($null -ne $shares[$key]) { $minimum[[string]$key] = [int]$shares[$key] } }
        } elseif ($shares) {
            foreach ($p in $shares.PSObject.Properties) { if ($null -ne $p.Value) { $minimum[$p.Name] = [int]$p.Value } }
        }
    }
    [pscustomobject]@{ Enabled = $enabled; MinimumShare = $minimum }
}

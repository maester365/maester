function Get-MtZtaThreshold {
    <#
    .SYNOPSIS
        Returns a per-test threshold value, sourced from
        `ZtaSettings.Thresholds.<TestId>` in maester-config.json with a
        caller-supplied default fallback.

    .DESCRIPTION
        Lets ZTA-aware tests expose their numeric thresholds (warn-band counts,
        fail-ratio cutoffs, sample caps) to operator tuning via maester-config
        without forking the test code.

        Lookup is two-step:

        1. `(Get-MtZta).ZtaSettings.Thresholds.<TestId>` if present and non-null
        2. otherwise the `-Default` parameter

        If `ZtaSettings` carries a hashtable / pscustomobject under `Thresholds`,
        we accept either shape — JSON-deserialised pscustomobject (default
        ConvertFrom-Json behaviour) or hashtable (operator passing
        `-AsHashtable`).

    .PARAMETER TestId
        The Maester test id (e.g. `MT.Zta.1001`). Conventionally same as the It
        block tag — that way the threshold key in maester-config matches what
        operators see in the report.

    .PARAMETER Default
        The threshold value to return when no operator override exists. Required —
        every threshold-bearing test must declare its built-in default.

    .EXAMPLE
        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 30
        $summary.IdentityFailed | Should -BeLessThan $threshold

    .EXAMPLE
        # In maester-config.json:
        # "ZtaSettings": {
        #   "Thresholds": {
        #     "MT.Zta.1001": 50,
        #     "MT.Zta.1140": 5
        #   }
        # }

    .LINK
        https://maester.dev/docs/commands/Get-MtZtaThreshold

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TestId,

        [Parameter(Mandatory = $true)]
        [object] $Default
    )

    $ctx = $script:MtZtaContext
    if (-not $ctx) { return $Default }
    if (-not $ctx.PSObject.Properties['ZtaSettings'] -or -not $ctx.ZtaSettings) { return $Default }
    $settings = $ctx.ZtaSettings

    $thresholds = $null
    if ($settings -is [hashtable]) {
        if ($settings.ContainsKey('Thresholds')) { $thresholds = $settings['Thresholds'] }
    }
    elseif ($settings.PSObject.Properties['Thresholds']) {
        $thresholds = $settings.Thresholds
    }
    if (-not $thresholds) { return $Default }

    $value = $null
    if ($thresholds -is [hashtable]) {
        if ($thresholds.ContainsKey($TestId)) { $value = $thresholds[$TestId] }
    }
    elseif ($thresholds.PSObject.Properties[$TestId]) {
        $value = $thresholds.$TestId
    }

    if ($null -eq $value) { return $Default }
    return $value
}

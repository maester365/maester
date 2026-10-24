function Get-MtPackPolicy {
    <#
    .SYNOPSIS
    Returns the organisation's pack policy (Maester Packs design, section 9.7), the strictest of every source.

    .DESCRIPTION
    Sources: the PackPolicy section of the run config, the MAESTER_PACK_POLICY environment variable (a
    path to a JSON file, or JSON text), and a machine-wide file that device management can deploy
    (%ProgramData%\Maester\pack-policy.json on Windows, /etc/maester/pack-policy.json elsewhere). Where they
    differ the strictest value wins: the lowest MaximumRisk, the publishers every source allows, the badges
    any source requires, AllowUnlisted and AllowExternalEnvironments only when no source turns them off,
    the longest CooldownHours, and RequireFreshBlocklist when any source sets it. TrustedSources from the
    environment and the machine file replace the config's, so a project config cannot widen them.

    Returns MaximumRisk (Low, Medium or High), AllowedPublishers, RequireBadge, AllowUnlisted,
    AllowExternalEnvironments, TrustedSources, CooldownHours, RequireFreshBlocklist, AllowedRuntimes and
    Sources (where each part came from).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The resolved run config, or $null.
        [Parameter()]
        [AllowNull()]
        [object] $RunConfig
    )

    $layers = [System.Collections.Generic.List[object]]::new()
    if ($RunConfig -and $RunConfig.PSObject.Properties['PackPolicy'] -and $RunConfig.PackPolicy) { $layers.Add([pscustomobject]@{ Name = 'config'; Policy = $RunConfig.PackPolicy }) }
    if ($env:MAESTER_PACK_POLICY) {
        try {
            $text = if (Test-Path -LiteralPath $env:MAESTER_PACK_POLICY -PathType Leaf) { Get-Content -LiteralPath $env:MAESTER_PACK_POLICY -Raw } else { $env:MAESTER_PACK_POLICY }
            $layers.Add([pscustomobject]@{ Name = 'MAESTER_PACK_POLICY'; Policy = ($text | ConvertFrom-Json -ErrorAction Stop) })
        } catch { throw "MAESTER_PACK_POLICY is not a JSON policy or a path to one: $($_.Exception.Message)" }
    }
    $machine = if ($IsWindows) { Join-Path $env:ProgramData 'Maester/pack-policy.json' } else { '/etc/maester/pack-policy.json' }
    if ($machine -and (Test-Path -LiteralPath $machine -PathType Leaf)) {
        try { $layers.Add([pscustomobject]@{ Name = $machine; Policy = (Get-Content -LiteralPath $machine -Raw | ConvertFrom-Json -ErrorAction Stop) }) }
        catch { throw "The machine pack policy '$machine' is not valid JSON: $($_.Exception.Message)" }
    }

    $riskOrder = @('Low', 'Medium', 'High')
    $policy = [ordered]@{
        MaximumRisk               = 'High'
        AllowedPublishers         = $null
        RequireBadge              = @()
        AllowUnlisted             = $true
        AllowExternalEnvironments = $true
        TrustedSources            = @()
        CooldownHours             = 72
        RequireFreshBlocklist     = $false
        AllowedRuntimes           = @('Script')
        Sources                   = @($layers | ForEach-Object { $_.Name })
    }
    $trustedFromConfig = @()
    $trustedOutside = $null
    foreach ($layer in $layers) {
        $p = $layer.Policy
        $value = { param($name) if ($p.PSObject.Properties[$name]) { $p.$name } else { $null } }
        $risk = & $value 'MaximumRisk'
        if ($risk) {
            if ($risk -notin $riskOrder) { throw "PackPolicy.MaximumRisk in $($layer.Name) must be Low, Medium or High, not '$risk'." }
            # JSON may say 'low': use the canonical spelling, as IndexOf is case-sensitive.
            $risk = $riskOrder | Where-Object { $_ -eq [string]$risk } | Select-Object -First 1
            if ($riskOrder.IndexOf($risk) -lt $riskOrder.IndexOf($policy.MaximumRisk)) { $policy.MaximumRisk = $risk }
        }
        # Read and assign arrays directly: pipeline enumeration turns an empty set into $null (unrestricted).
        if ($p.PSObject.Properties['AllowedPublishers'] -and $null -ne $p.AllowedPublishers) {
            $list = @($p.AllowedPublishers | ForEach-Object { ([string]$_).ToLowerInvariant() })
            if ($null -eq $policy.AllowedPublishers) { $policy.AllowedPublishers = $list }
            else { $policy.AllowedPublishers = @($policy.AllowedPublishers | Where-Object { $_ -in $list }) }
        }
        $badges = & $value 'RequireBadge'
        if ($badges) { $policy.RequireBadge = @(@($policy.RequireBadge) + @($badges) | Select-Object -Unique) }
        foreach ($flag in 'AllowUnlisted', 'AllowExternalEnvironments') {
            $v = & $value $flag
            if ($null -ne $v -and -not [bool]$v) { $policy[$flag] = $false }
        }
        $hours = & $value 'CooldownHours'
        if ($null -ne $hours -and [int]$hours -gt $policy.CooldownHours) { $policy.CooldownHours = [int]$hours }
        if ([bool](& $value 'RequireFreshBlocklist')) { $policy.RequireFreshBlocklist = $true }
        $runtimes = & $value 'AllowedRuntimes'
        if ($null -ne $runtimes) { $policy.AllowedRuntimes = @($policy.AllowedRuntimes | Where-Object { $_ -in @($runtimes) }) }
        $trusted = & $value 'TrustedSources'
        if ($null -ne $trusted) {
            if ($layer.Name -eq 'config') { $trustedFromConfig = @($trusted) }
            else { $trustedOutside = @(@($trustedOutside) + @($trusted) | Where-Object { $_ } | Select-Object -Unique) }
        }
    }
    $policy.TrustedSources = if ($null -ne $trustedOutside) { $trustedOutside } else { $trustedFromConfig }
    [pscustomobject]$policy
}

function Test-MtPackPolicy {
    <#
    .SYNOPSIS
    Returns why the pack policy does not allow a pack, or $null when it does.

    .DESCRIPTION
    Checked at install, restore and every run (Maester Packs design, section 9.7). A pack that ships with
    Maester is always allowed. Every other pack is unlisted until Maester Packs exists, so with
    AllowUnlisted turned off only the packs in TrustedSources (repositories such as
    github.com/contoso/maester-checks, or digests) are allowed. The accepted risk level must not be above
    MaximumRisk, and the publisher must be in AllowedPublishers when that restriction is present.
    An empty allowlist denies every non-built-in pack; null or an absent property is unrestricted.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Policy,
        [Parameter(Mandatory)] [string] $PackId,
        [Parameter()] [string] $Publisher,
        [Parameter()] [string] $Source,
        [Parameter()] [string] $Digest,
        [Parameter()] [string] $Risk = 'Low',
        [Parameter()] [switch] $BuiltIn
    )

    if ($BuiltIn) { return $null }
    $riskOrder = @('Low', 'Medium', 'High')
    $rank = { param($r) $riskOrder.IndexOf(($riskOrder | Where-Object { $_ -eq [string]$r } | Select-Object -First 1)) }
    # An unknown risk ranks above High, so it is refused.
    $riskRank = & $rank $Risk
    if ($riskRank -lt 0) { $riskRank = $riskOrder.Count }
    if ($riskRank -gt (& $rank $Policy.MaximumRisk)) {
        return "The pack policy allows packs up to $($Policy.MaximumRisk) risk, and $PackId is $Risk risk."
    }
    if ($null -ne $Policy.AllowedPublishers -and (-not $Publisher -or $Publisher.ToLowerInvariant() -notin $Policy.AllowedPublishers)) {
        return "The pack policy does not allow packs from the publisher '$Publisher'."
    }
    if (-not $Policy.AllowUnlisted) {
        $trusted = @($Policy.TrustedSources | Where-Object { $_ -and (($Source -and ($Source -eq $_ -or $Source.StartsWith("$_/", [System.StringComparison]::OrdinalIgnoreCase) -or "github.com/$Source" -eq $_)) -or ($Digest -and $Digest -eq $_)) })
        if ($trusted.Count -eq 0) { return "The pack policy does not allow unlisted packs, and $PackId is not in its TrustedSources. Until Maester Packs lists packs, every pack from GitHub is unlisted." }
    }
    $null
}

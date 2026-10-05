function Resolve-MtRunConfig {
    <#
    .SYNOPSIS
    Resolves the run configuration for Invoke-Maester (design section 7.3).

    .DESCRIPTION
    Exactly one source is used:

    1. -Config: a path, a config object (hashtable or PSCustomObject), or an array of either, merged
       left to right. The run is hermetic: config files under -Path are not read.
    2. Otherwise the MAESTER_CONFIG environment variable, a path to a config file.
    3. Otherwise the config files discovered from -Path, with the 2.x rules (Get-MtMaesterConfig).

    For sources 1 and 2 the configuration shipped with the module is the lowest layer, so test
    severities keep their defaults. The result has the shape of the 2.x config object (ConfigSource,
    GlobalSettings, TestSettings, TestSettingsHash) plus the 3.0 sections, each always present.

    .EXAMPLE
    Resolve-MtRunConfig -Path ./tests -Config @{ Selection = @{ TestId = 'MT.1005' } }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Folder that config discovery starts from.
        [Parameter()]
        [string] $Path,

        # Tenant ID used to find maester-config.<TenantId>.json during discovery.
        [Parameter()]
        [string] $TenantId,

        # Explicit configuration: a path, an object, or an array of paths and objects.
        [Parameter()]
        [object] $Config
    )

    $sourceNames = [System.Collections.Generic.List[string]]::new()
    $layers = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $Config) {
        foreach ($item in @($Config)) {
            $layers.Add((ConvertTo-MtConfigLayer -InputObject $item))
            $sourceNames.Add($(if ($item -is [string]) { Split-Path -Path $item -Leaf } else { '-Config' }))
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($env:MAESTER_CONFIG)) {
        $layers.Add((ConvertTo-MtConfigLayer -InputObject $env:MAESTER_CONFIG))
        $sourceNames.Add("MAESTER_CONFIG ($(Split-Path -Path $env:MAESTER_CONFIG -Leaf))")
    }

    if ($layers.Count -gt 0) {
        # Shipped defaults first, then the explicit source.
        $resolved = Get-MtShippedMaesterConfig
        foreach ($layer in $layers) {
            $resolved = Merge-MtConfigLayer -Base $resolved -Overlay $layer
        }
        $configSource = $sourceNames -join ', '
    } else {
        $discoveryPath = if ($Path) { $Path } else { (Get-Location).Path }
        $resolved = Get-MtMaesterConfig -Path $discoveryPath -TenantId $TenantId
        if ($null -eq $resolved) { $resolved = [pscustomobject]@{} }
        $configSource = if ($resolved.PSObject.Properties['ConfigSource']) { $resolved.ConfigSource } else { $null }
    }

    Complete-MtRunConfig -Config $resolved -ConfigSource $configSource
}

function Get-MtShippedMaesterConfig {
    <#
    .SYNOPSIS
    Returns the maester-config.json shipped with the module (the default severities), or an empty config.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $shipped = Join-Path (Get-MtMaesterTestFolderPath) -ChildPath 'maester-config.json'
    if (-not (Test-Path -LiteralPath $shipped)) {
        # Source checkout: the shipped file lives in the repository's tests folder.
        $shipped = Join-Path $PSScriptRoot -ChildPath '../../../tests/maester-config.json'
    }
    if (Test-Path -LiteralPath $shipped) {
        return ConvertTo-MtConfigLayer -InputObject (Resolve-Path -LiteralPath $shipped).Path
    }
    [pscustomobject]@{}
}

function ConvertTo-MtConfigLayer {
    <#
    .SYNOPSIS
    Turns a config path, hashtable or object into a PSCustomObject layer.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) { return [pscustomobject]@{} }
    if ($InputObject -is [System.IO.FileInfo]) { $InputObject = $InputObject.FullName }
    if ($InputObject -is [string]) {
        if (-not (Test-Path -LiteralPath $InputObject -PathType Leaf)) {
            throw "The Maester config file '$InputObject' does not exist."
        }
        $text = Get-Content -LiteralPath $InputObject -Raw
        if ([string]::IsNullOrWhiteSpace($text)) { return [pscustomobject]@{} }
        try {
            return $text | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "The Maester config file '$InputObject' is not valid JSON: $($_.Exception.Message)"
        }
    }
    # Normalise hashtables and nested objects through JSON so every layer has the same shape.
    $InputObject | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Merge-MtConfigLayer {
    <#
    .SYNOPSIS
    Merges a higher config layer over a lower one.

    .DESCRIPTION
    TestSettings merge per Id, per property. Every other object merges per key, recursively. Arrays and
    scalar values replace, so an empty array in a higher layer clears the lower one.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Base,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Overlay
    )

    if ($null -eq $Base) { return $Overlay }
    if ($null -eq $Overlay) { return $Base }

    $result = $Base.PSObject.Copy()
    foreach ($property in $Overlay.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value
        $existing = $result.PSObject.Properties[$name]

        if ($name -eq 'TestSettings' -and $existing) {
            $result.$name = @(Merge-MtTestSettingList -Base @($existing.Value) -Overlay @($value))
        } elseif ($existing -and $existing.Value -is [pscustomobject] -and $value -is [pscustomobject]) {
            $result.$name = Merge-MtConfigLayer -Base $existing.Value -Overlay $value
        } elseif ($existing) {
            $result.$name = $value
        } else {
            $result | Add-Member -MemberType NoteProperty -Name $name -Value $value
        }
    }
    $result
}

function Merge-MtTestSettingList {
    <#
    .SYNOPSIS
    Merges two TestSettings arrays per Id (case-insensitive), per property, keeping the base order.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()] [object[]] $Base = @(),
        [Parameter()] [object[]] $Overlay = @()
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $index = @{}
    foreach ($row in $Base) {
        if ($null -eq $row) { continue }
        $copy = $row.PSObject.Copy()
        $rows.Add($copy)
        if ($row.Id) { $index[([string]$row.Id).ToLowerInvariant()] = $copy }
    }
    foreach ($row in $Overlay) {
        if ($null -eq $row) { continue }
        $key = if ($row.Id) { ([string]$row.Id).ToLowerInvariant() } else { $null }
        if ($key -and $index.ContainsKey($key)) {
            $target = $index[$key]
            foreach ($p in $row.PSObject.Properties) {
                if ($target.PSObject.Properties[$p.Name]) { $target.($p.Name) = $p.Value }
                else { $target | Add-Member -MemberType NoteProperty -Name $p.Name -Value $p.Value }
            }
        } else {
            $copy = $row.PSObject.Copy()
            $rows.Add($copy)
            if ($key) { $index[$key] = $copy }
        }
    }
    $rows.ToArray()
}

function Complete-MtRunConfig {
    <#
    .SYNOPSIS
    Adds the sections and lookup tables every consumer of the run config expects.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Config,

        [Parameter()]
        [AllowNull()]
        [string] $ConfigSource
    )

    $defaults = [ordered]@{
        GlobalSettings = [pscustomobject]@{}
        TestSettings   = @()
        Metadata       = [pscustomobject]@{}
        Selection      = [pscustomobject]@{}
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Config.PSObject.Properties[$key] -or $null -eq $Config.$key) {
            $Config | Add-Member -MemberType NoteProperty -Name $key -Value $defaults[$key] -Force
        }
    }

    $selectionDefaults = [ordered]@{
        BuiltIn            = 'All'
        DefaultAction      = 'Run'
        Tag                = @()
        ExcludeTag         = @()
        TestId             = @()
        ExcludeTestId      = @()
        IncludePreview     = $false
        IncludeLongRunning = $false
        OnUnknownId        = 'Warn'
    }
    foreach ($key in $selectionDefaults.Keys) {
        if (-not $Config.Selection.PSObject.Properties[$key] -or $null -eq $Config.Selection.$key) {
            $Config.Selection | Add-Member -MemberType NoteProperty -Name $key -Value $selectionDefaults[$key] -Force
        }
    }
    foreach ($key in 'Tag', 'ExcludeTag', 'TestId', 'ExcludeTestId') {
        $Config.Selection.$key = @($Config.Selection.$key | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if ($Config.Selection.DefaultAction -notin 'Run', 'Skip') {
        throw "Selection.DefaultAction must be 'Run' or 'Skip', not '$($Config.Selection.DefaultAction)'."
    }
    if ($Config.Selection.OnUnknownId -notin 'Warn', 'Ignore', 'Error') {
        throw "Selection.OnUnknownId must be 'Warn', 'Ignore' or 'Error', not '$($Config.Selection.OnUnknownId)'."
    }

    $Config | Add-Member -MemberType NoteProperty -Name 'ConfigSource' -Value $ConfigSource -Force

    # Lookup by Id (case-insensitive), as 2.x provides.
    $hash = @{}
    foreach ($row in @($Config.TestSettings)) {
        if ($null -ne $row -and $row.Id -and -not $hash.ContainsKey([string]$row.Id)) { $hash[[string]$row.Id] = $row }
    }
    $Config | Add-Member -MemberType NoteProperty -Name 'TestSettingsHash' -Value $hash -Force
    $Config
}

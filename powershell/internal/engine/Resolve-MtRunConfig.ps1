function Resolve-MtRunConfig {
    <#
    .SYNOPSIS
    Resolves the run configuration for Invoke-Maester (design section 7.3).

    .DESCRIPTION
    Exactly one source is used:

    1. -Config: a path, a config object (hashtable or PSCustomObject), or an array of either, merged
       left to right. The run is hermetic: config files under -Path are not read.
    2. Otherwise the MAESTER_CONFIG environment variable, a path to a config file.
    3. Otherwise the config files discovered from -Path: maester-config.json (searched in -Path,
       -Path/tests and up to five parent folders), then custom/maester-config.json, then
       maester-config.<TenantId>.json. Each file is an optional layer and each merges over the one
       before; a Custom file without a root file beside it is honoured.

    The configuration shipped with the module is always the lowest layer, so test severities keep their
    defaults. Merge rules: TestSettings per Id and property, other objects per key, arrays replace.
    The result has the shape of the 2.x config object (ConfigSource,
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
        $resolved = Get-MtShippedMaesterConfig
        $found = @(Find-MtConfigFile -Path $discoveryPath -TenantId $TenantId)
        $discoveryResolved = Resolve-Path -LiteralPath $discoveryPath -ErrorAction SilentlyContinue
        $discoveryFull = $(if ($discoveryResolved) { $discoveryResolved.ProviderPath } else { $discoveryPath }).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        foreach ($file in $found) {
            $layer = ConvertTo-MtConfigLayer -InputObject $file.Path
            Write-Verbose "Using Maester config file: $($file.Path)"
            # A file in a parent folder applies to every run below it. Say so when it changes what runs or
            # what the tenant is assumed to have, so a stray or planted file cannot quietly reduce coverage.
            $outside = -not ([System.IO.Path]::GetFullPath($file.Path)).StartsWith($discoveryFull, [System.StringComparison]::OrdinalIgnoreCase)
            $sensitive = @('Selection', 'Environment', 'Output' | Where-Object { $layer.PSObject.Properties[$_] })
            if ($outside -and $sensitive.Count -gt 0) {
                Write-Warning "The Maester config file '$($file.Path)' is outside '$discoveryPath' and sets $($sensitive -join ', '). Check that it is meant to apply to this run, or pass the config with -Config."
            }
            if ($file.Kind -eq 'Root') { Test-MtShippedConfigCopy -Config $layer -Path $file.Path }
            if ($file.Kind -eq 'Tenant') { Write-MtTenantMergeWarning -Tenant $layer -Found $found }
            $resolved = Merge-MtConfigLayer -Base $resolved -Overlay $layer
        }
        $configSource = if ($found.Count -gt 0) { ($found | ForEach-Object { $_.Name }) -join ', ' } else { 'defaults' }
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

function Find-MtConfigFile {
    <#
    .SYNOPSIS
    Finds the config files of a test folder, lowest layer first: root, Custom overlay, tenant file.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter()] [string] $TenantId
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        # A file is never the config itself (-Config is for that): look for the config files from its folder.
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
        $Path = Split-Path -Path (Resolve-Path -LiteralPath $Path).Path -Parent
    }
    $Path = (Resolve-Path -LiteralPath $Path).Path

    $root = Find-MtConfigFileUpward -Path $Path -FileName 'maester-config.json'
    if ($root) { [pscustomobject]@{ Kind = 'Root'; Path = $root; Name = 'maester-config.json' } }

    $customSearch = if ($root) { @(Split-Path $root -Parent) } else { @($Path, (Join-Path $Path 'tests')) }
    foreach ($folder in $customSearch) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        $custom = Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq 'custom' } |
            ForEach-Object { Join-Path $_.FullName 'maester-config.json' } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ($custom -and $custom -ne $root) {
            [pscustomobject]@{ Kind = 'Custom'; Path = $custom; Name = "$(Split-Path (Split-Path $custom -Parent) -Leaf)/maester-config.json" }
            break
        }
    }

    if ($TenantId -as [guid]) {
        $tenantFile = Find-MtConfigFileUpward -Path $Path -FileName "maester-config.$TenantId.json"
        if ($tenantFile) { [pscustomobject]@{ Kind = 'Tenant'; Path = $tenantFile; Name = "maester-config.$TenantId.json" } }
    }
}

function Find-MtConfigFileUpward {
    <#
    .SYNOPSIS
    Looks for a file in a folder, its tests subfolder and up to five parent folders (the 2.x search order).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $FileName
    )

    $candidates = @((Join-Path $Path $FileName), (Join-Path (Join-Path $Path 'tests') $FileName))
    $current = $Path
    for ($i = 1; $i -le 5; $i++) {
        $parent = Split-Path -Path $current -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
        $candidates += Join-Path $current $FileName
    }
    $shipped = [System.IO.Path]::GetFullPath((Join-Path (Get-MtMaesterTestFolderPath) 'maester-config.json'))
    foreach ($c in $candidates) {
        if (-not (Test-Path -LiteralPath $c -PathType Leaf)) { continue }
        # The shipped file is the defaults layer, not a user file.
        if ([System.IO.Path]::GetFullPath($c) -eq $shipped) { continue }
        return (Resolve-Path -LiteralPath $c).Path
    }
    $null
}

function Test-MtShippedConfigCopy {
    <#
    .SYNOPSIS
    Warns when a user's maester-config.json looks like a copy of the file Maester 2.x shipped.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Config,
        [Parameter(Mandatory)] [string] $Path
    )

    $rows = @($Config.TestSettings)
    if ($rows.Count -ge 300 -and -not ($rows | Where-Object { $_ -and -not $_.PSObject.Properties['Title'] })) {
        Write-Warning ("'$Path' looks like a copy of the maester-config.json that Maester 2.x shipped. Its $($rows.Count) rows " +
            'override the built-in severities. Keep only the rows you changed; Update-MaesterTests can do this for you.')
    }
}

function Write-MtTenantMergeWarning {
    <#
    .SYNOPSIS
    Warns once when a tenant-specific config file inherits settings it would have hidden in Maester 2.x.

    .DESCRIPTION
    Maester 2.x loaded maester-config.<TenantId>.json instead of maester-config.json. 3.0 merges it over
    the base files, so the tenant inherits GlobalSettings it does not set itself.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Tenant,
        [Parameter(Mandatory)] [object[]] $Found
    )

    if (-not ($Found | Where-Object Kind -EQ 'Root')) { return }
    $root = ConvertTo-MtConfigLayer -InputObject ($Found | Where-Object Kind -EQ 'Root' | Select-Object -First 1).Path
    $baseKeys = @($root.GlobalSettings.PSObject.Properties | Where-Object { $null -ne $_.Value -and "$($_.Value)" -ne '' } | ForEach-Object { $_.Name })
    $tenantKeys = @($Tenant.GlobalSettings.PSObject.Properties.Name)
    $inherited = @($baseKeys | Where-Object { $_ -notin $tenantKeys })
    if ($inherited.Count -gt 0) {
        Write-Warning ("The tenant config file now merges over maester-config.json instead of replacing it, so it inherits: " +
            "$($inherited -join ', '). Set these in the tenant file to override them.")
    }
}

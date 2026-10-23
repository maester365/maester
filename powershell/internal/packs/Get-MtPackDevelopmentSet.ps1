function Get-MtPackDevelopmentSet {
    <#
    .SYNOPSIS
    Returns the pack that holds a path, as a loader-gate row, for running a pack's tests while it is written (Invoke-MtTest -Path).

    .DESCRIPTION
    The pack folder is the nearest folder, from -Path up to five levels, that holds maester-pack.json. It
    is loaded from where it is, not from the store, the way a custom test is: the person running it is
    its author. Its manifest must be valid. Its Gallery modules are taken from PSModulePath at the exact
    version the manifest pins. The row replaces any installed pack with the same ID for this session, its
    connectors are registered, and its module is loaded fresh on every call so edits are picked up.

    Returns $null when -Path is not inside a pack.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $Path)

    $folder = (Resolve-Path -LiteralPath $Path).Path
    if (Test-Path -LiteralPath $folder -PathType Leaf) { $folder = Split-Path -Path $folder -Parent }
    $root = $null
    for ($i = 0; $i -le 5 -and $folder; $i++) {
        if (Test-Path -LiteralPath (Join-Path $folder 'maester-pack.json') -PathType Leaf) { $root = $folder; break }
        $parent = Split-Path -Path $folder -Parent
        if (-not $parent -or $parent -eq $folder) { break }
        $folder = $parent
    }
    if (-not $root) { return $null }

    $builtIn = [bool](Get-MtBuiltInPack | Where-Object { $_.Root -eq $root })
    # A pack of the maester365 organisation (such as the demo pack) may use the reserved names, as Test-MtPack
    # -Official allows: run from a folder, its author is the person running it, as for a custom test. Installing
    # it still needs the repository to belong to the organisation.
    $official = $builtIn
    if (-not $official) {
        try {
            $raw = Get-Content -LiteralPath (Join-Path $root 'maester-pack.json') -Raw | ConvertFrom-Json -ErrorAction Stop
            $official = [string]$raw.Id -match '^(maester|maester365)\.' -or [string]$raw.Publisher -in 'maester', 'maester365'
        } catch { $official = $false }
    }
    $read = Read-MtPackManifest -Path $root -Official:$official
    if ($read.Errors.Count -gt 0) { throw "The pack in '$root' has a problem: $(@($read.Errors | ForEach-Object { $_.Message }) -join ' ') Run Test-MtPack for the full list." }
    $m = $read.Manifest
    $modules = foreach ($d in @($m.Uses.Modules)) {
        $found = Find-MtPackModuleFolder -Name $d.Name -Version ([string]$d.Version)
        if (-not $found) { $found = Find-MtPackModuleFolder -Name $d.Name -Version ([string]$d.Version) -Root (Get-MtPackHome).Modules }
        if (-not $found) { throw "The pack $($m.Id) uses the module $($d.Name) $($d.Version), which is not installed. Run Install-Module $($d.Name) -RequiredVersion $($d.Version)." }
        [pscustomobject]@{ Name = [string]$d.Name; Version = [string]$d.Version; Source = 'External'; Path = $found }
    }
    $pack = [pscustomobject][ordered]@{
        Id = [string]$m.Id; Version = [string]$m.Version; BuiltIn = $builtIn; Root = $root; Manifest = $m; Entry = $null; Modules = @($modules)
        Status = 'Ready'; ReasonCode = $null; Reason = $null; TestIds = @()
    }

    if ($null -eq $script:__MtPackSet) { $null = Initialize-MtPackSet -WarningAction SilentlyContinue }
    $script:__MtPackSet = @(@($script:__MtPackSet | Where-Object { $_.Id -ne $pack.Id }) + $pack)
    $null = Register-MtPackService -PackSet $script:__MtPackSet
    if ($script:__MtPackModules) {
        foreach ($key in @($script:__MtPackModules.Keys | Where-Object { $_ -like "$($pack.Id)|*" })) { $script:__MtPackModules.Remove($key) }
    }
    $pack
}

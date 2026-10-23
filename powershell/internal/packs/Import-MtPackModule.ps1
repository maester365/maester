function Import-MtPackModule {
    <#
    .SYNOPSIS
    Loads a pack that passed the loader gate into its own private module (Maester Packs design, section 4.4).

    .DESCRIPTION
    A pack's helpers, connector files and tests are loaded together into one private module, so its tests
    can call its helpers. Files are dot-sourced by path, never from text, so execution policy and App
    Control apply to them. The module sees Maester's exported commands and nothing private, and exports
    nothing into Maester's scope; the engine calls its functions inside it.

    Before the files load:
    - its Gallery modules are imported into it by the paths Resolve-MtPackSet checked, the modules each one
      requires first, so a RequiredModules entry is met by the pinned version and never by another version
      that happens to be in the store or on PSModulePath. A required module is imported globally, because
      that is where PowerShell looks for it; after each import the modules it was given are checked, and the
      load stops if any is not the pinned copy;
    - the functions that each pack it requires lists in Exports are added to it.

    The module is cached for the session by pack ID and digest, so a run and Connect-Maester share one.
    Throws with the load error.
    #>
    [CmdletBinding()]
    [OutputType([psmoduleinfo])]
    param(
        # A Ready row from Resolve-MtPackSet.
        [Parameter(Mandatory)] [pscustomobject] $Pack,
        # Every row from Resolve-MtPackSet, to find required packs.
        [Parameter()] [object[]] $PackSet = @()
    )

    if (-not $script:__MtPackModules) { $script:__MtPackModules = @{} }
    $key = "$($Pack.Id)|$(if ($Pack.Entry -and $Pack.Entry.Digest) { $Pack.Entry.Digest } else { $Pack.Root })"
    if ($script:__MtPackModules.ContainsKey($key)) { return $script:__MtPackModules[$key].Module }
    if ($Pack.Status -ne 'Ready') { throw "The pack $($Pack.Id) cannot be loaded: $($Pack.Reason)" }

    $m = $Pack.Manifest
    $files = [System.Collections.Generic.List[string]]::new()
    # Helpers are .ps1 files, as the manifest schema says: dot-sourcing a .psm1 would run it as a program.
    foreach ($folder in $m.Helpers) {
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Pack.Root $folder) -Recurse -File -Filter '*.ps1' -ErrorAction Stop | Sort-Object FullName)) { $files.Add($f.FullName) }
    }
    foreach ($c in $m.Connectors) {
        $full = Join-Path $Pack.Root $c.File
        if (-not $files.Contains($full)) { $files.Add($full) }
    }
    foreach ($folder in $m.Suites) {
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Pack.Root $folder) -Recurse -File -Filter 'Test.*.ps1' -ErrorAction Stop | Sort-Object FullName)) { $files.Add($f.FullName) }
    }

    # Modules: the checked store comes first on PSModulePath, once per session, for modules the lock file does not pin.
    $store = (Get-MtPackHome).Modules
    if ($Pack.Modules.Count -gt 0 -and -not (@($env:PSModulePath -split [System.IO.Path]::PathSeparator) -contains $store)) {
        $env:PSModulePath = $store + [System.IO.Path]::PathSeparator + $env:PSModulePath
    }
    # A module the pack runs in a child process is not imported here.
    $declared = @($m.Uses.Modules | Where-Object { -not ($_.PSObject.Properties['Process'] -and $_.Process -eq 'Child') } | ForEach-Object { [string]$_.Name })
    $pinned = @($Pack.Modules)
    # Each module after the pinned modules it requires, so they are loaded from their checked paths first.
    $order = [System.Collections.Generic.List[object]]::new()
    $requiredPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $visiting = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $toVersion = { param($v) $parts = @(([string]$v -replace '-.*$', '') -split '\.'); while ($parts.Count -lt 2) { $parts += '0' }; [version]($parts -join '.') }
    $visit = {
        param($row)
        if (($order | Where-Object Path -EQ $row.Path) -or -not $visiting.Add($row.Path)) { return }
        foreach ($r in (Get-MtPackModuleRequirement -Path $row.Path)) {
            $candidates = @($pinned | Where-Object Name -EQ $r.Name)
            # The lowest pinned version it accepts, which is the one the closure pinned for it.
            $dep = if ($r.Version) { $candidates | Where-Object { (& $toVersion $_.Version) -ge (& $toVersion $r.Version) } | Sort-Object { & $toVersion $_.Version } | Select-Object -First 1 }
            if (-not $dep) { $dep = $candidates | Sort-Object { & $toVersion $_.Version } -Descending | Select-Object -First 1 }
            if ($dep) { $null = $requiredPaths.Add($dep.Path); & $visit $dep }
        }
        $order.Add($row)
    }
    foreach ($row in ($pinned | Where-Object { $_.Name -in $declared })) { & $visit $row }
    $moduleList = @($order | ForEach-Object { [pscustomobject]@{ File = (Join-Path $_.Path "$($_.Name).psd1"); Global = $requiredPaths.Contains($_.Path) } })
    $pinnedPaths = @{}
    foreach ($row in $pinned) { $pinnedPaths[$row.Name] = @(@($pinnedPaths[$row.Name]) + [System.IO.Path]::GetFullPath($row.Path).TrimEnd('/', '\') | Where-Object { $_ }) }

    # Exports of required packs.
    $imports = [System.Collections.Generic.List[object]]::new()
    foreach ($r in @($m.RequiredPacks)) {
        $required = $PackSet | Where-Object { $_.Id -eq $r.Id } | Select-Object -First 1
        if (-not $required) { throw "The pack $($Pack.Id) requires $($r.Id), which is not installed." }
        $requiredModule = Import-MtPackModule -Pack $required -PackSet $PackSet
        foreach ($name in $required.Manifest.Exports) {
            $function = & $requiredModule { param($n) Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue } $name
            if ($function) { $imports.Add([pscustomobject]@{ Name = $name; ScriptBlock = $function.ScriptBlock }) }
        }
    }

    $name = "MaesterPack_$($Pack.Id -replace '[^A-Za-z0-9]', '_')"
    # Nothing is exported: New-Module would import exports into Maester's own scope (see Import-MtCustomTestFile).
    $loader = [scriptblock]::Create(@'
param($__MtPackModuleList, $__MtPackPinnedPaths, $__MtPackImports, $__MtPackFiles)
foreach ($__MtPackModule in $__MtPackModuleList) {
    $__MtPackLoaded = Import-Module -Name $__MtPackModule.File -Global:$__MtPackModule.Global -PassThru -ErrorAction Stop | Select-Object -First 1
    # A module it requires that the lock file pins must be the pinned copy, not another version PowerShell found.
    foreach ($__MtPackUsed in @($__MtPackLoaded.RequiredModules)) {
        if (-not $__MtPackPinnedPaths.ContainsKey($__MtPackUsed.Name)) { continue }
        if (@($__MtPackPinnedPaths[$__MtPackUsed.Name]) -notcontains [System.IO.Path]::GetFullPath($__MtPackUsed.ModuleBase).TrimEnd('/', '\')) {
            throw "The module $($__MtPackLoaded.Name) loaded $($__MtPackUsed.Name) $($__MtPackUsed.Version) from '$($__MtPackUsed.ModuleBase)', which is not the version the lock file pins. Remove that version from the pack module store, or run Install-MtPack again to review it."
        }
    }
}
foreach ($__MtPackImport in $__MtPackImports) { Set-Item -Path "function:script:$($__MtPackImport.Name)" -Value $__MtPackImport.ScriptBlock }
foreach ($__MtPackFile in $__MtPackFiles) { . $__MtPackFile }
Remove-Variable -Name __MtPackModule, __MtPackLoaded, __MtPackUsed, __MtPackImport, __MtPackFile, __MtPackModuleList, __MtPackPinnedPaths, __MtPackImports, __MtPackFiles -ErrorAction SilentlyContinue
Export-ModuleMember -Function @() -Variable @() -Alias @()
'@)
    $module = New-Module -Name $name -ScriptBlock $loader -ArgumentList $moduleList, $pinnedPaths, $imports.ToArray(), $files.ToArray() -ErrorAction Stop
    $script:__MtPackModules[$key] = [pscustomobject]@{ Module = $module; Pack = $Pack }
    if (-not $script:__MtPackModuleOwner) { $script:__MtPackModuleOwner = @{} }
    $script:__MtPackModuleOwner[$name] = $Pack
    $module
}

function Get-MtCallingPack {
    <#
    .SYNOPSIS
    Returns the pack whose code called a Maester command, from the caller's session state, or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter()] [AllowNull()] [System.Management.Automation.SessionState] $SessionState)

    if (-not $SessionState -or -not $SessionState.Module -or -not $script:__MtPackModuleOwner) { return $null }
    if ($script:__MtPackModuleOwner.ContainsKey($SessionState.Module.Name)) { return $script:__MtPackModuleOwner[$SessionState.Module.Name] }
    $null
}

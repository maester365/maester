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
    - its Gallery modules are imported into it by path, with the pack module store first on PSModulePath so
      the modules they require resolve to the checked copies;
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
    foreach ($folder in $m.Helpers) {
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Pack.Root $folder) -Recurse -File -Include '*.ps1', '*.psm1' -ErrorAction Stop | Sort-Object FullName)) { $files.Add($f.FullName) }
    }
    foreach ($c in $m.Connectors) {
        $full = Join-Path $Pack.Root $c.File
        if (-not $files.Contains($full)) { $files.Add($full) }
    }
    foreach ($folder in $m.Suites) {
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Pack.Root $folder) -Recurse -File -Filter 'Test.*.ps1' -ErrorAction Stop | Sort-Object FullName)) { $files.Add($f.FullName) }
    }

    # Modules: the checked store comes first on PSModulePath, once per session.
    $store = (Get-MtPackHome).Modules
    if ($Pack.Modules.Count -gt 0 -and -not (@($env:PSModulePath -split [System.IO.Path]::PathSeparator) -contains $store)) {
        $env:PSModulePath = $store + [System.IO.Path]::PathSeparator + $env:PSModulePath
    }
    # A module the pack runs in a child process is not imported here.
    $declared = @($m.Uses.Modules | Where-Object { -not ($_.PSObject.Properties['Process'] -and $_.Process -eq 'Child') } | ForEach-Object { [string]$_.Name })
    $modulePaths = @($Pack.Modules | Where-Object { $_.Name -in $declared } | ForEach-Object { Join-Path $_.Path "$($_.Name).psd1" })

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
param($__MtPackModulePaths, $__MtPackImports, $__MtPackFiles)
foreach ($__MtPackModulePath in $__MtPackModulePaths) { Import-Module -Name $__MtPackModulePath -ErrorAction Stop }
foreach ($__MtPackImport in $__MtPackImports) { Set-Item -Path "function:script:$($__MtPackImport.Name)" -Value $__MtPackImport.ScriptBlock }
foreach ($__MtPackFile in $__MtPackFiles) { . $__MtPackFile }
Remove-Variable -Name __MtPackModulePath, __MtPackImport, __MtPackFile, __MtPackModulePaths, __MtPackImports, __MtPackFiles -ErrorAction SilentlyContinue
Export-ModuleMember -Function @() -Variable @() -Alias @()
'@)
    $module = New-Module -Name $name -ScriptBlock $loader -ArgumentList $modulePaths, $imports.ToArray(), $files.ToArray() -ErrorAction Stop
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

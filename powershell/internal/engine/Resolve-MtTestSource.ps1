function Resolve-MtTestSource {
    <#
    .SYNOPSIS
    Works out which test files a run uses: the built-in suites and the custom tests (design section 7.2).

    .DESCRIPTION
    Built-in tests always run from the module unless -SkipBuiltIn (or Selection.BuiltIn = None) is set.
    -Path is where the user's custom tests and config live:

    - An explicit -Path is scanned recursively. If it does not exist, that is a warning and built-ins
      still run (an error with -SkipBuiltIn); config discovery starts from the nearest existing parent.
    - Without -Path, the current folder is scanned only when it is recognisably a Maester folder: it has
      a maester-config file, a Custom folder, a 2.x suite folder, or a *.Tests.ps1 or Test.*.ps1 file.
      In a Maester source checkout the custom root is ./tests/Custom.

    Returns BuiltInRoot, CustomRoot, ConfigSearchPath, BuiltInFiles, CustomFiles, Error and Messages.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The -Path given to Invoke-Maester (or PesterConfiguration.Run.Path), if any.
        [Parameter()]
        [AllowEmptyString()]
        [string] $Path,

        # Run custom tests only.
        [Parameter()]
        [switch] $SkipBuiltIn
    )

    $messages = [System.Collections.Generic.List[pscustomobject]]::new()
    $builtInRoot = (Get-MtMaesterTestFolderPath)
    if (Test-Path -LiteralPath $builtInRoot) { $builtInRoot = (Resolve-Path -LiteralPath $builtInRoot).Path }
    $customRoot = $null
    $configSearchPath = $null
    $errorMessage = $null

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (Test-Path -LiteralPath $Path) {
            $customRoot = (Resolve-Path -LiteralPath $Path).Path
            $configSearchPath = $customRoot
        } else {
            $parent = $Path
            while ($parent -and -not (Test-Path -LiteralPath $parent)) { $parent = Split-Path -Path $parent -Parent }
            $configSearchPath = if ($parent) { (Resolve-Path -LiteralPath $parent).Path } else { (Get-Location).Path }
            if ($SkipBuiltIn) {
                $errorMessage = "The path '$Path' does not exist."
            } else {
                $messages.Add([pscustomobject]@{ Level = 'Warning'; Text = "The path '$Path' does not exist. Only the built-in tests run." })
            }
        }
    } else {
        $cwd = (Get-Location).Path
        $configSearchPath = $cwd
        if (Test-Path -LiteralPath (Join-Path $cwd 'powershell/tests/pester.ps1')) {
            # Maester source checkout: the built-in tests are ./tests; custom tests are ./tests/Custom.
            $devCustom = Join-Path $cwd 'tests/Custom'
            if (Test-Path -LiteralPath $devCustom) { $customRoot = (Resolve-Path -LiteralPath $devCustom).Path }
            $configSearchPath = Join-Path $cwd 'tests'
        } elseif (Test-MtMaesterFolder -Path $cwd) {
            $customRoot = $cwd
        } else {
            $messages.Add([pscustomobject]@{ Level = 'Information'; Text = 'Running the built-in tests. To also run custom tests, pass the folder that holds them with -Path.' })
        }
    }

    # Files under the built-in root are built-ins wherever the custom root is, except its Custom folder.
    $builtInAll = @()
    if (Test-Path -LiteralPath $builtInRoot) { $builtInAll = @(Get-MtBuiltInPesterFile -BuiltInRoot $builtInRoot) }
    $allBuiltIn = [System.Collections.Generic.HashSet[string]]::new([string[]]$builtInAll, [System.StringComparer]::OrdinalIgnoreCase)
    $builtInFiles = if ($SkipBuiltIn) { @() } else { $builtInAll }

    $customFiles = @()
    if ($customRoot) {
        $customFiles = @(Get-ChildItem -LiteralPath $customRoot -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName } | Where-Object { -not $allBuiltIn.Contains($_) } | Sort-Object)
    }

    $customNativeCount = if ($customRoot) { @(Get-ChildItem -LiteralPath $customRoot -Recurse -File -Filter 'Test.*.ps1' -ErrorAction SilentlyContinue).Count } else { 0 }
    if ($SkipBuiltIn -and -not $errorMessage -and $customFiles.Count -eq 0 -and $customNativeCount -eq 0) {
        $errorMessage = if ($customRoot) { "No test files found in '$customRoot'." } else { 'No custom tests to run. Pass the folder that holds them with -Path.' }
    }

    [pscustomobject]@{
        BuiltInRoot      = $builtInRoot
        CustomRoot       = $customRoot
        ConfigSearchPath = $configSearchPath
        BuiltInFiles     = $builtInFiles
        CustomFiles      = $customFiles
        Error            = $errorMessage
        Messages         = $messages.ToArray()
    }
}

function Get-MtBuiltInPesterFile {
    <#
    .SYNOPSIS
    Lists the built-in Pester test files: every *.Tests.ps1 under the built-in root except its Custom folder.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $BuiltInRoot
    )

    $customPrefix = (Join-Path $BuiltInRoot 'Custom') + [System.IO.Path]::DirectorySeparatorChar
    Get-ChildItem -LiteralPath $BuiltInRoot -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName } |
        Where-Object { -not $_.StartsWith($customPrefix, [System.StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object
}

function Test-MtMaesterFolder {
    <#
    .SYNOPSIS
    Returns $true when a folder is recognisably a Maester test folder (design section 7.2).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $suiteFolders = 'Custom', 'Maester', 'cis', 'cisa', 'EIDSCA', 'orca', 'XSPM', 'ad'
    foreach ($candidate in @($Path, (Join-Path $Path 'tests'))) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { continue }
        if (Get-ChildItem -LiteralPath $candidate -File -Filter 'maester-config*.json' -ErrorAction SilentlyContinue) { return $true }
    }
    $children = Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($children | Where-Object { $_.PSIsContainer -and $_.Name -in $suiteFolders }) { return $true }
    if ($children | Where-Object { -not $_.PSIsContainer -and ($_.Name -like '*.Tests.ps1' -or $_.Name -like 'Test.*.ps1') }) { return $true }
    $false
}

function Get-MtSupersededTest {
    <#
    .SYNOPSIS
    Finds custom Pester tests that are stale copies of built-in tests (design section 8).

    .DESCRIPTION
    A Pester test outside the built-in suites is superseded when its ID is a built-in ID, a previous ID
    of a built-in, or the ID of a built-in that was since removed (Maester.LegacyIds.json), or when the
    literal start of its name begins with a built-in family's parent ID and a dot. A superseded test is
    not run and produces no row. A file whose every test is superseded is excluded as a whole, so its
    BeforeAll and BeforeDiscovery blocks do not run either.

    Returns ExcludeFiles, ExcludeLines (file:line), and Items (Id, File, Line, MatchedBy) for the result.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Inventory rows of the custom files (Get-MtPesterFileInventory).
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $CustomInventory,

        # Inventory rows of the built-in files.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $BuiltInInventory,

        # IDs of the built-in native tests.
        [Parameter()]
        [string[]] $BuiltInId = @()
    )

    $builtInIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($r in $BuiltInInventory) { if ($r.Id) { $null = $builtInIds.Add($r.Id) } }
    foreach ($id in $BuiltInId) { if ($id) { $null = $builtInIds.Add($id) } }

    $legacy = Get-MtLegacyIdTable
    $legacyIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $legacy.Entries) { $null = $legacyIds.Add($e.LegacyId) }
    $familyPrefixes = @($legacy.FamilyPrefixes)
    foreach ($r in $BuiltInInventory) {
        if (-not $r.IsStatic) {
            $parent = Get-MtFamilyParentId -LiteralPrefix $r.LiteralPrefix
            if ($parent -and "$parent." -notin $familyPrefixes) { $familyPrefixes += "$parent." }
        }
    }

    $items = [System.Collections.Generic.List[pscustomobject]]::new()
    $byFile = @{}
    foreach ($r in $CustomInventory) {
        if (-not $r.Line) { continue }
        if (-not $byFile.ContainsKey($r.File)) { $byFile[$r.File] = @{ Total = 0; Superseded = [System.Collections.Generic.List[object]]::new() } }
        $byFile[$r.File].Total++

        $matchedBy = $null
        if ($r.Id -and $builtInIds.Contains($r.Id)) { $matchedBy = 'BuiltInId' }
        elseif ($r.Id -and $legacyIds.Contains($r.Id)) { $matchedBy = 'PreviousId' }
        else {
            $start = if ($r.Id) { $r.Id } else { $r.LiteralPrefix }
            if ($start -and ($familyPrefixes | Where-Object { $start.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })) { $matchedBy = 'FamilyPrefix' }
        }
        if ($matchedBy) {
            $item = [pscustomobject]@{ Id = $(if ($r.Id) { $r.Id } else { $r.LiteralPrefix }); File = $r.File; Line = $r.Line; MatchedBy = $matchedBy }
            $items.Add($item)
            $byFile[$r.File].Superseded.Add($item)
        }
    }

    $excludeFiles = [System.Collections.Generic.List[string]]::new()
    $excludeLines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $byFile.Keys) {
        $entry = $byFile[$file]
        if ($entry.Superseded.Count -eq 0) { continue }
        if ($entry.Superseded.Count -eq $entry.Total) {
            $excludeFiles.Add($file)
        } else {
            foreach ($i in $entry.Superseded) { $excludeLines.Add("$($i.File):$($i.Line)") }
        }
    }

    [pscustomobject]@{
        ExcludeFiles = @($excludeFiles | Sort-Object)
        ExcludeLines = $excludeLines.ToArray()
        Items        = $items.ToArray()
    }
}

function Get-MtLegacyIdTable {
    <#
    .SYNOPSIS
    Reads Maester.LegacyIds.json, the previous IDs of built-in tests. Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not $script:__MtLegacyIdTable) {
        $file = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/Maester.LegacyIds.json'
        $script:__MtLegacyIdTable = if (Test-Path -LiteralPath $file) {
            Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        } else {
            [pscustomobject]@{ Entries = @(); FamilyPrefixes = @() }
        }
    }
    $script:__MtLegacyIdTable
}

function Get-MtTestFileOrigin {
    <#
    .SYNOPSIS
    Returns Source and Suite for a test file (design appendix A.6), from the nearest suite.json.

    .DESCRIPTION
    A built-in file takes its suite's Source and Id. A custom file takes the Source and Id of a
    suite.json between it and the custom root, else Source = Custom and Suite = Custom.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $File,
        [Parameter(Mandatory)] [string] $Root,
        [Parameter()] [switch] $BuiltIn,
        [Parameter()] [hashtable] $Cache = @{}
    )

    $folder = Split-Path -Path $File -Parent
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    while ($folder -and $folder.Length -ge $rootFull.Length) {
        if (-not $Cache.ContainsKey($folder)) {
            $manifest = Join-Path $folder 'suite.json'
            $Cache[$folder] = if (Test-Path -LiteralPath $manifest) {
                try { Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json } catch { $null }
            } else { $null }
        }
        $suite = $Cache[$folder]
        if ($suite -and $suite.Source) {
            return [pscustomobject]@{ Source = [string]$suite.Source; Suite = [string]$suite.Id }
        }
        $parent = Split-Path -Path $folder -Parent
        if ($parent -eq $folder) { break }
        $folder = $parent
    }
    if ($BuiltIn) { return [pscustomobject]@{ Source = 'Maester'; Suite = 'Maester' } }
    [pscustomobject]@{ Source = 'Custom'; Suite = 'Custom' }
}

function Get-MtOutermostPath {
    <#
    .SYNOPSIS
    Removes paths that are inside another path of the list, so Pester does not discover a folder twice.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowEmptyCollection()] [string[]] $Path = @()
    )

    $sep = [System.IO.Path]::DirectorySeparatorChar
    $full = @($Path | Where-Object { $_ } | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd($sep) } | Select-Object -Unique)
    foreach ($p in $full) {
        $inside = $full | Where-Object { $_ -ne $p -and $p.StartsWith($_ + $sep, [System.StringComparison]::OrdinalIgnoreCase) }
        if (-not $inside) { $p }
    }
}

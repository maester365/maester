function Resolve-MtTestSource {
    <#
    .SYNOPSIS
    Works out which test files a run uses: the built-in suites and the custom tests (design section 7.2).

    .DESCRIPTION
    Built-in tests always run from the module unless -SkipBuiltIn (or Selection.BuiltIn = None) is set.
    -Path is where the user's custom tests and config live:

    - An explicit -Path is scanned for native tests (Test.*.ps1) in any folder under it. Pester-format
      tests (*.Tests.ps1) are found only inside a folder named Custom: -Path itself, or the Custom folders
      under it. If -Path does not exist, that is a warning and built-ins still run (an error with
      -SkipBuiltIn); config discovery starts from the nearest existing parent.
    - Without -Path, only the Custom folder of the current folder is scanned (or the current folder, when
      it is a Custom folder); config files are looked for in the current folder. In a Maester source
      checkout the custom root is ./tests/Custom.
    - Folders are scanned at most three levels deep (Get-MtCustomTestFile), so a -Path that holds
      unrelated content, such as a repository, is not walked to the bottom.

    Returns BuiltInRoot, CustomRoot, ConfigSearchPath, BuiltInFiles, CustomFiles (Pester-format),
    CustomNativeFiles, Error and Messages.
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
            # -Path can be one test file: its folder is where the config files are looked for.
            $configSearchPath = if (Test-Path -LiteralPath $customRoot -PathType Leaf) { Split-Path -Path $customRoot -Parent } else { $customRoot }
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
        $customParent = $cwd
        if (Test-Path -LiteralPath (Join-Path $cwd 'powershell/tests/pester.ps1')) {
            # Maester source checkout: the built-in tests are ./tests; custom tests are ./tests/custom.
            $customParent = Join-Path $cwd 'tests'
            $configSearchPath = $customParent
        }
        $customFolder = if ((Split-Path -Path $cwd -Leaf) -ieq 'custom') {
            Get-Item -LiteralPath $cwd
        } else {
            Get-ChildItem -LiteralPath $customParent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq 'custom' } | Select-Object -First 1
        }
        if ($customFolder) {
            $customRoot = $customFolder.FullName
        } else {
            $messages.Add([pscustomobject]@{ Level = 'Information'; Text = 'Running the built-in tests. To also run custom tests, put them in a Custom folder here or pass the folder that holds them with -Path.' })
        }
    }

    # Files under the built-in root are built-ins wherever the custom root is, except its Custom folder.
    $builtInAll = @()
    if (Test-Path -LiteralPath $builtInRoot) { $builtInAll = @(Get-MtBuiltInPesterFile -BuiltInRoot $builtInRoot) }
    $allBuiltIn = [System.Collections.Generic.HashSet[string]]::new([string[]]$builtInAll, [System.StringComparer]::OrdinalIgnoreCase)
    $builtInFiles = if ($SkipBuiltIn) { @() } else { $builtInAll }

    $customFiles = @()
    $customNativeFiles = @()
    if ($customRoot) {
        $customFiles = @(Get-MtCustomTestFile -Root $customRoot -Format Pester | Where-Object { -not $allBuiltIn.Contains($_) })
        # Native tests under the built-in root are built-ins (they come from the catalog), except in its Custom folder.
        $builtInPrefix = [System.IO.Path]::GetFullPath($builtInRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        $builtInCustomPrefix = $builtInPrefix + 'custom' + [System.IO.Path]::DirectorySeparatorChar
        $customNativeFiles = @(Get-MtCustomTestFile -Root $customRoot -Format Native |
                Where-Object { -not $_.StartsWith($builtInPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or $_.StartsWith($builtInCustomPrefix, [System.StringComparison]::OrdinalIgnoreCase) })

        # Pester-format files outside a Custom folder are not run; most are 2.x copies of built-in tests.
        $outsideCustom = @(Get-MtCustomTestFile -Root $customRoot -Format Pester -OutsideCustom | Where-Object { -not $allBuiltIn.Contains($_) })
        if ($outsideCustom.Count -gt 0) {
            $messages.Add([pscustomobject]@{ Level = 'Warning'; Text = ("$($outsideCustom.Count) Pester-format test file(s) under '$customRoot' are not in a Custom folder and were not run. " +
                    "Move your own Pester-format tests into a Custom folder, and run Update-MaesterTests -Path '$customRoot' to remove copies of tests that now ship with Maester.") })
        }
    }

    if ($SkipBuiltIn -and -not $errorMessage -and $customFiles.Count -eq 0 -and $customNativeFiles.Count -eq 0) {
        $errorMessage = if ($customRoot) { "No test files found in '$customRoot'." } else { 'No custom tests to run. Put them in a Custom folder here or pass the folder that holds them with -Path.' }
    }

    [pscustomobject]@{
        BuiltInRoot       = $builtInRoot
        CustomRoot        = $customRoot
        ConfigSearchPath  = $configSearchPath
        BuiltInFiles      = $builtInFiles
        CustomFiles       = $customFiles
        CustomNativeFiles = $customNativeFiles
        Error             = $errorMessage
        Messages          = $messages.ToArray()
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

    $customPrefix = (Join-Path $BuiltInRoot 'custom') + [System.IO.Path]::DirectorySeparatorChar
    Get-ChildItem -LiteralPath $BuiltInRoot -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName } |
        Where-Object { -not $_.StartsWith($customPrefix, [System.StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object
}

function Get-MtCustomTestFile {
    <#
    .SYNOPSIS
    Lists the custom test files of one format under a custom root (design section 7.2).

    .DESCRIPTION
    Native tests (Test.*.ps1) are found in any folder under the root. Pester-format tests (*.Tests.ps1) are
    found only inside a folder named Custom: the root itself when it is in one, or the Custom folders under
    it. A root that is a file is returned as it is when it has the format's file name. Folders are scanned
    at most -Depth levels below the root, and below each Custom folder.

    -OutsideCustom returns instead the Pester-format files that are left out because they are not in a
    Custom folder.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [ValidateSet('Native', 'Pester')] [string] $Format,
        [Parameter()] [switch] $OutsideCustom,
        # How many folder levels below a scanned folder are looked at: Custom/a/b/c/Test.X.ps1 with the default.
        [Parameter()] [int] $Depth = 3
    )

    $filter = if ($Format -eq 'Native') { 'Test.*.ps1' } else { '*.Tests.ps1' }
    if (Test-Path -LiteralPath $Root -PathType Leaf) {
        # An explicit file is run whatever folder it is in.
        $item = Get-Item -LiteralPath $Root
        if (-not $OutsideCustom -and $item.Name -like $filter) { $item.FullName }
        return
    }

    $sep = [System.IO.Path]::DirectorySeparatorChar
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    # A filesystem root keeps its separator: trimmed, '/' is empty and 'C:\' is the drive-relative 'C:'.
    if ($rootFull -ne [System.IO.Path]::GetPathRoot($rootFull)) { $rootFull = $rootFull.TrimEnd($sep) }
    $rootInCustom = @($rootFull -split '[\\/]' | Where-Object { $_ -ieq 'custom' }).Count -gt 0
    if ($Format -eq 'Native' -or $rootInCustom) {
        if ($OutsideCustom) { return }
        $folders = @($rootFull)
    } else {
        $folders = @(Get-MtOutermostPath -Path @(Get-ChildItem -LiteralPath $rootFull -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -ieq 'custom' } | ForEach-Object { $_.FullName }))
    }

    if ($OutsideCustom) {
        $prefixes = @($folders | ForEach-Object { $_ + $sep })
        Get-ChildItem -LiteralPath $rootFull -Recurse -Depth $Depth -File -Filter $filter -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName } |
            Where-Object { $file = $_; -not ($prefixes | Where-Object { $file.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) } |
            Sort-Object
        return
    }
    @(foreach ($folder in $folders) {
            Get-ChildItem -LiteralPath $folder -Recurse -Depth $Depth -File -Filter $filter -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }) | Sort-Object -Unique
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

function Get-MtNativeTestInventory {
    <#
    .SYNOPSIS
    Discovers native tests (Test.<ID>.ps1) under a folder and resolves what their suite adds.

    .DESCRIPTION
    Reads every Test.*.ps1 file statically (Read-MtNativeTest) and applies the nearest suite.json between
    the file and the root: suite tags, default category, Source, Suite, help URL template and
    RequiresMaester (design section 3.6). Adds the effective tag set (suite tags + Id + Tag + Preview /
    LongRunning) and the resolved help URL. Tests that share an ID or a function name get a DuplicateId
    error. A built-in root skips its Custom folder.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Folders or files to scan.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Path,

        # The root that suite.json files are searched up to.
        [Parameter()]
        [string] $Root,

        # The tests ship with Maester.
        [Parameter()]
        [switch] $BuiltIn
    )

    $files = foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { (Resolve-Path -LiteralPath $p).Path }
        elseif (Test-Path -LiteralPath $p -PathType Container) {
            $resolved = (Resolve-Path -LiteralPath $p).Path
            $customPrefix = (Join-Path $resolved 'Custom') + [System.IO.Path]::DirectorySeparatorChar
            Get-ChildItem -LiteralPath $resolved -Recurse -File -Filter 'Test.*.ps1' -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName } |
                Where-Object { -not ($BuiltIn -and $_.StartsWith($customPrefix, [System.StringComparison]::OrdinalIgnoreCase)) }
        }
    }
    $files = @($files | Sort-Object -Unique)
    if (-not $Root) { $Root = if ($Path.Count -gt 0 -and (Test-Path -LiteralPath $Path[0] -PathType Container)) { (Resolve-Path -LiteralPath $Path[0]).Path } else { $null } }

    $suiteCache = @{}
    $tests = foreach ($file in $files) {
        $test = Read-MtNativeTest -Path $file -BuiltIn:$BuiltIn
        $suite = if ($Root) { Get-MtSuiteManifest -File $file -Root $Root -Cache $suiteCache } else { $null }
        Complete-MtNativeTest -Test $test -Suite $suite -BuiltIn:$BuiltIn
    }
    $tests = @($tests)

    # Duplicate IDs and function names. Neither runs.
    foreach ($group in ($tests | Where-Object Id | Group-Object { $_.Id.ToLowerInvariant() } | Where-Object Count -GT 1)) {
        foreach ($t in $group.Group) {
            $others = ($group.Group | Where-Object { $_.File -ne $t.File } | ForEach-Object { $_.File }) -join ', '
            $t.Errors.Add([pscustomobject]@{ Code = 'DuplicateId'; Message = "Another test has the ID $($t.Id): $others."; Line = $t.Line })
        }
    }
    foreach ($group in ($tests | Where-Object FunctionName | Group-Object { $_.FunctionName.ToLowerInvariant() } | Where-Object Count -GT 1)) {
        foreach ($t in $group.Group) {
            $t.Errors.Add([pscustomobject]@{ Code = 'DuplicateId'; Message = "Another test file defines the function $($t.FunctionName)."; Line = $t.Line })
        }
    }
    $tests
}

function Complete-MtNativeTest {
    <#
    .SYNOPSIS
    Adds Source, Suite, Category, effective tags and help URL to a test read by Read-MtNativeTest.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Test,
        [Parameter()] [AllowNull()] [object] $Suite,
        [Parameter()] [switch] $BuiltIn
    )

    $source = if ($Suite -and $Suite.Source) { [string]$Suite.Source } elseif ($BuiltIn) { 'Maester' } else { 'Custom' }
    $suiteId = if ($Suite -and $Suite.Id) { [string]$Suite.Id } elseif ($BuiltIn) { 'Maester' } else { 'Custom' }
    $category = if ($Test.Category) { $Test.Category } elseif ($Suite -and $Suite.DefaultCategory) { [string]$Suite.DefaultCategory } elseif ($BuiltIn) { $suiteId } else { 'Custom' }

    $tags = [System.Collections.Generic.List[string]]::new()
    foreach ($t in @($(if ($Suite) { $Suite.Tags } else { @() })) + @($Test.Id) + @($Test.Tag)) {
        if ($t -and -not ($tags | Where-Object { $_ -eq $t })) { $tags.Add([string]$t) }
    }
    if ($Test.Preview -and -not ($tags -contains 'Preview')) { $tags.Add('Preview') }
    if ($Test.LongRunning -and -not ($tags -contains 'LongRunning')) { $tags.Add('LongRunning') }

    $helpUrl = $Test.HelpUrl
    if (-not $helpUrl -and $Test.Id) {
        $template = if ($Suite -and $Suite.HelpUrlTemplate) { [string]$Suite.HelpUrlTemplate } elseif ($BuiltIn) { 'https://maester.dev/docs/tests/{Id}' } else { $null }
        if ($template) { $helpUrl = $template.Replace('{Id}', $Test.Id) }
    }

    if ($Suite -and $Suite.RequiresMaester -and -not $Test.RequiresMaester) {
        $Test.RequiresMaester = [string]$Suite.RequiresMaester
        if ([version]$Test.RequiresMaester -gt $ExecutionContext.SessionState.Module.Version) {
            $Test.Errors.Add([pscustomobject]@{ Code = 'RequiresNewerMaester'; Message = "The suite requires Maester $($Test.RequiresMaester) or later; this is $($ExecutionContext.SessionState.Module.Version)."; Line = 1 })
        }
    }

    $Test | Add-Member -NotePropertyMembers ([ordered]@{
            Source       = $source
            Suite        = $suiteId
            Category     = $category
            EffectiveTag = $tags.ToArray()
            HelpUrl      = $helpUrl
            Format       = 'Native'
        }) -Force
    $Test
}

function Get-MtSuiteManifest {
    <#
    .SYNOPSIS
    Returns the nearest suite.json between a file and a root folder, or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $File,
        [Parameter(Mandatory)] [string] $Root,
        [Parameter()] [hashtable] $Cache = @{}
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $folder = Split-Path -Path $File -Parent
    while ($folder -and $folder.Length -ge $rootFull.Length) {
        if (-not $Cache.ContainsKey($folder)) {
            $manifest = Join-Path $folder 'suite.json'
            $Cache[$folder] = if (Test-Path -LiteralPath $manifest) {
                try { Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -ErrorAction Stop }
                catch { Write-Warning "Ignoring '$manifest': it is not valid JSON."; $null }
            } else { $null }
        }
        if ($Cache[$folder]) { return $Cache[$folder] }
        $parent = Split-Path -Path $folder -Parent
        if ($parent -eq $folder) { break }
        $folder = $parent
    }
    $null
}

function Get-MtTestCatalog {
    <#
    .SYNOPSIS
    Returns the built-in native tests: the shipped Maester.TestCatalog.json, or a scan of tests/ in a source checkout.

    .DESCRIPTION
    Each row has the attribute properties plus Source, Suite, Category, EffectiveTag, HelpUrl, FunctionName,
    File, Parameters and MarkdownPath (design appendix A.4). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Rebuild the cache.
        [Parameter()]
        [switch] $Refresh
    )

    if ($script:__MtTestCatalog -and -not $Refresh) { return $script:__MtTestCatalog }
    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $catalogFile = Join-Path $moduleBase 'Maester.TestCatalog.json'
    $rows = if (Test-Path -LiteralPath $catalogFile) {
        $catalog = Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json
        foreach ($t in $catalog.Tests) {
            # The catalog stores repository-relative paths; Markdown is bundled by ID.
            $t | Add-Member -NotePropertyName Errors -NotePropertyValue ([System.Collections.Generic.List[pscustomobject]]::new()) -Force
            $t | Add-Member -NotePropertyName BuiltIn -NotePropertyValue $true -Force
            $t
        }
    } else {
        $root = Get-MtMaesterTestFolderPath
        if (Test-Path -LiteralPath $root) { Get-MtNativeTestInventory -Path $root -Root $root -BuiltIn } else { @() }
    }
    $script:__MtTestCatalog = @($rows)
    $script:__MtTestCatalog
}

function Import-MtCustomTestFile {
    <#
    .SYNOPSIS
    Loads a custom native test file into its own private module (design section 5.1).

    .DESCRIPTION
    The module sees Maester's exported commands but not its private functions, so a custom file cannot
    replace engine functions. The file is loaded by path, so $PSScriptRoot resolves. Returns the module,
    or throws with the load error.
    #>
    [CmdletBinding()]
    [OutputType([psmoduleinfo])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    $hash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant()))).Replace('-', '').Substring(0, 12)
    $name = "MaesterCustomTest_$hash"
    # Nothing is exported: New-Module imports exports into the caller's scope, which is Maester's own, so
    # an exported custom function could shadow an engine function. The engine invokes tests inside the
    # module's scope instead.
    $loader = [scriptblock]::Create(". `$args[0]; Export-ModuleMember -Function @() -Variable @() -Alias @()")
    New-Module -Name $name -ScriptBlock $loader -ArgumentList $Path -ErrorAction Stop
}

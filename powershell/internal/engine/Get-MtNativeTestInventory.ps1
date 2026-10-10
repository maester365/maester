function Get-MtNativeTestInventory {
    <#
    .SYNOPSIS
    Discovers native tests (Test.<ID>.ps1) under a folder and resolves what their suite adds.

    .DESCRIPTION
    Reads every Test.*.ps1 file statically (Read-MtNativeTest) and applies the nearest suite.json between
    the file and the root: suite tags, Source, Suite, help URL template and RequiresMaester (design
    section 3.6). Adds the derived values (test attribute design, section 2.3): Block and the resolved help
    URL. Tests that share an ID or a function name get a DuplicateId error. A built-in root skips its
    Custom folder.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [object[]])]
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
            $customPrefix = (Join-Path $resolved 'custom') + [System.IO.Path]::DirectorySeparatorChar
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
    Adds Source, Suite, Block, the suite's tags and the help URL to a test read by Read-MtNativeTest.

    .DESCRIPTION
    Block is kept on the result row for 2.x consumers and for XML test-case names. It is the display name of
    Product when the taxonomy registry knows it, else Product as written, else Feature, else the suite's
    Name, else Custom.

    SuiteTag holds the Tags of the suite.json. Like the test's own Tag they are matched by -Tag and
    -ExcludeTag (Get-MtSelectionTag), but they are not written to a result row: a row's Tag holds the tags
    the test's author wrote.
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
    $block = if ($Test.Product) { Get-MtProductName -Product $Test.Product }
    elseif ($Test.Feature) { [string]$Test.Feature }
    elseif ($Suite -and $Suite.PSObject.Properties['Name'] -and $Suite.Name) { [string]$Suite.Name }
    else { 'Custom' }

    $suiteTags = [string[]]@($(if ($Suite -and $Suite.PSObject.Properties['Tags']) { $Suite.Tags }) | Where-Object { $_ } | ForEach-Object { [string]$_ } | Select-Object -Unique)

    $helpUrl = $Test.HelpUrl
    if (-not $helpUrl -and $Test.Id) {
        $template = if ($Suite -and $Suite.HelpUrlTemplate) { [string]$Suite.HelpUrlTemplate } elseif ($BuiltIn) { 'https://maester.dev/docs/tests/{Id}' } else { $null }
        if ($template) { $helpUrl = $template.Replace('{Id}', $Test.Id) }
    }

    if ($Suite -and $Suite.RequiresMaester -and -not $Test.RequiresMaester) {
        $Test.RequiresMaester = [string]$Suite.RequiresMaester
        $required = ConvertTo-MtRequiredVersion -Value $Test.RequiresMaester
        if (-not $required) {
            $Test.Errors.Add([pscustomobject]@{ Code = 'InvalidMetadata'; Message = "RequiresMaester in suite.json is '$($Test.RequiresMaester)', which is not a version number, for example 3.0."; Line = 1 })
        } elseif ($required -gt $ExecutionContext.SessionState.Module.Version) {
            $Test.Errors.Add([pscustomobject]@{ Code = 'RequiresNewerMaester'; Message = "The suite requires Maester $($Test.RequiresMaester) or later; this is $($ExecutionContext.SessionState.Module.Version)."; Line = 1 })
        }
    }

    $Test | Add-Member -NotePropertyMembers ([ordered]@{
            Source       = $source
            Suite        = $suiteId
            Block        = $block
            SuiteTag     = $suiteTags
            HelpUrl      = $helpUrl
            Format       = 'Native'
        }) -Force
    # The skip text for a test that returns $null without saying why, when the suite has its own wording.
    if ($Suite -and $Suite.PSObject.Properties['NoResultReason'] -and $Suite.NoResultReason) {
        $Test | Add-Member -NotePropertyName NoResultReason -NotePropertyValue ([string]$Suite.NoResultReason) -Force
    }
    $Test
}

function Get-MtSelectionTag {
    <#
    .SYNOPSIS
    Returns the tags that -Tag and -ExcludeTag match for a native test (test attribute design, section 5.1).

    .DESCRIPTION
    Own: the tags the test's author wrote and the Tags of its suite.json and, for a test shipped with
    Maester, its own ID. Legacy: for a test shipped with Maester, the tags it carried in Maester 2.x
    (assets/Maester.LegacyTags.json), so that every 2.x tag keeps selecting the tests it selected.

    The legacy tags and the ID are used for selection only. They are never written to a result row.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Test
    )

    $own = [System.Collections.Generic.List[string]]::new()
    foreach ($tag in @($Test.Tag) + @($(if ($Test.PSObject.Properties['SuiteTag']) { $Test.SuiteTag }))) { if ($tag) { $own.Add([string]$tag) } }
    $legacy = @()
    if ($Test.PSObject.Properties['BuiltIn'] -and $Test.BuiltIn -and $Test.Id) {
        $own.Add([string]$Test.Id)
        $table = Get-MtLegacyTagTable
        $tags = $null
        if ($table.ByTest.TryGetValue([string]$Test.Id, [ref] $tags)) { $legacy = $tags }
    }
    [pscustomobject]@{ Own = $own.ToArray(); Legacy = @($legacy) }
}

function Get-MtLegacyTagTable {
    <#
    .SYNOPSIS
    Returns the Maester 2.x tags of the built-in tests (assets/Maester.LegacyTags.json). Cached for the session.

    .DESCRIPTION
    ByTest maps a test ID to the 2.x tags it carried, and Replacement maps a tag to the typed selector that
    takes its place, for the tags that have one. Both are case-insensitive. The file is generated once by
    build/golden/Export-MtLegacyTagTable.ps1; tests added after Maester 3.0 are not in it.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not $script:__MtLegacyTagTable) {
        $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
        $byTest = [System.Collections.Generic.Dictionary[string, string[]]]::new($ignoreCase)
        $replacement = [System.Collections.Generic.Dictionary[string, string]]::new($ignoreCase)
        $file = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/Maester.LegacyTags.json'
        if (Test-Path -LiteralPath $file) {
            $lists = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new($ignoreCase)
            foreach ($entry in @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).Tags)) {
                if ($entry.PSObject.Properties['Replacement'] -and $entry.Replacement) { $replacement[[string]$entry.Tag] = [string]$entry.Replacement }
                foreach ($id in @($entry.Tests)) {
                    if (-not $lists.ContainsKey([string]$id)) { $lists[[string]$id] = [System.Collections.Generic.List[string]]::new() }
                    $lists[[string]$id].Add([string]$entry.Tag)
                }
            }
            foreach ($id in $lists.Keys) { $byTest[$id] = $lists[$id].ToArray() }
        }
        $script:__MtLegacyTagTable = [pscustomobject]@{ ByTest = $byTest; Replacement = $replacement }
    }
    $script:__MtLegacyTagTable
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
    Each row has the attribute properties plus Source, Suite, Block, SuiteTag, HelpUrl, FunctionName,
    File, Parameters and MarkdownPath (design appendix A.4). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [object[]])]
    param(
        # Rebuild the cache.
        [Parameter()]
        [switch] $Refresh
    )

    if ($null -ne $script:__MtTestCatalog -and -not $Refresh) { return $script:__MtTestCatalog }
    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $catalogFile = Join-Path $moduleBase 'Maester.TestCatalog.json'
    $rows = if (Test-Path -LiteralPath $catalogFile) {
        $catalog = Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json
        # JSON null for an empty list would read back as @($null), a list of one, so the gates would apply.
        $arrayProperties = @((Get-MtTestSchema).Properties.GetEnumerator() | Where-Object { $_.Value.Type -eq 'string[]' } | ForEach-Object { $_.Key }) + 'SuiteTag'
        foreach ($t in $catalog.Tests) {
            foreach ($name in $arrayProperties) {
                if ($t.PSObject.Properties[$name]) { $t.$name = [string[]]@($t.$name | Where-Object { $null -ne $_ -and $_ -ne '' }) }
            }
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

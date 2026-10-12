function Get-MtSuiteFramework {
    <#
    .SYNOPSIS
    Reads the frameworks a suite.json declares and their framework files (test attribute design, section 6).

    .DESCRIPTION
    A suite that ships the catalogue of a published benchmark says so in its suite.json:

        "Frameworks": [ { "Key": "cis-m365", "Version": "7.0.0" } ]

    The catalogue is frameworks/<Key>.json beside the suite.json: Framework (the key), Name, Version, Url and
    Requirements, each with an Id, optional Related references to controls of other frameworks, and any other
    fact, such as Level or Criticality. A test maps itself to a requirement with Control = '<Key>:<Id>'
    (Resolve-MtTestBenchmark). A Tests list on a requirement and an IdPrefix in the declaration were how a test
    was mapped before; both are ignored.

    Returns one object per declared framework: Key, Version, Name, Url, SuiteFile, File, Requirements (the
    entries of the file), ById (requirement Id to the requirement and its Related references, case-sensitive),
    Problems and IsValid.

    Nothing is thrown. Problems lists what is wrong with the declaration or the file, each message starting
    with the path of the file. A run warns about a framework with problems and takes no Benchmark from it; the
    catalog build fails on them (Get-MtFrameworkProblem). Each file is read once per call.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The content of the suite.json.
        [Parameter(Mandatory)] [AllowNull()] [object] $Suite,

        # The folder of the suite.json.
        [Parameter(Mandatory)] [string] $Folder
    )

    if ($Suite -isnot [pscustomobject] -or -not $Suite.PSObject.Properties['Frameworks']) { return }
    $suiteFile = Join-Path $Folder 'suite.json'
    $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
    $controlPattern = (Get-MtTestSchema).Properties.Control.Pattern
    $seenKeys = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)

    foreach ($entry in @($Suite.Frameworks | Where-Object { $null -ne $_ })) {
        $problems = [System.Collections.Generic.List[string]]::new()
        $read = { param($name) if ($entry -is [pscustomobject] -and $entry.PSObject.Properties[$name] -and $null -ne $entry.$name) { [string]$entry.$name } else { $null } }
        $framework = [pscustomobject]@{
            Key          = & $read 'Key'
            Version      = & $read 'Version'
            Name         = $null
            Url          = $null
            SuiteFile    = $suiteFile
            File         = $null
            Requirements = @()
            ById         = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
            Problems     = $problems
            IsValid      = $false
        }

        # The declaration. The key names the file, so it is the framework key of a Control reference: no path.
        if (-not $framework.Key -or $framework.Key -cnotmatch '^[a-z0-9][a-z0-9.\-]*$') {
            $problems.Add("${suiteFile}: a Frameworks entry has the Key '$($framework.Key)'. A key is lowercase letters, digits, dots and hyphens, for example cis-m365.")
            $framework
            continue
        }
        if (-not $seenKeys.Add($framework.Key)) { $problems.Add("${suiteFile}: the framework '$($framework.Key)' is declared more than once.") }

        # The file.
        $file = Join-Path $Folder "frameworks/$($framework.Key).json"
        $framework.File = $file
        $content = $null
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            $problems.Add("${file}: the file does not exist. The suite.json declares the framework '$($framework.Key)'.")
        } else {
            try {
                $content = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($content -isnot [pscustomobject]) { $problems.Add("${file}: it must hold one JSON object."); $content = $null }
            } catch {
                $problems.Add("${file}: it is not valid JSON.")
                $content = $null
            }
        }
        if ($content) {
            $declared = if ($content.PSObject.Properties['Framework']) { [string]$content.Framework } else { $null }
            if ($declared -cne $framework.Key) { $problems.Add("${file}: Framework is '$declared'; the suite.json declares the key '$($framework.Key)'.") }
            if ($content.PSObject.Properties['Name'] -and $content.Name) { $framework.Name = [string]$content.Name }
            if ($content.PSObject.Properties['Url'] -and $content.Url) { $framework.Url = [string]$content.Url }
            $fileVersion = if ($content.PSObject.Properties['Version'] -and $null -ne $content.Version) { [string]$content.Version } else { $null }
            if (-not $framework.Version) { $framework.Version = $fileVersion }
            elseif ($fileVersion -and $fileVersion -cne $framework.Version) { $problems.Add("${file}: Version is '$fileVersion'; the suite.json declares the version '$($framework.Version)'.") }

            $requirements = @($(if ($content.PSObject.Properties['Requirements']) { $content.Requirements }) | Where-Object { $null -ne $_ })
            $framework.Requirements = $requirements
            $seenIds = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
            foreach ($requirement in $requirements) {
                # An ID such as 1.10 written as a number would be read as 1.1.
                $id = if ($requirement -is [pscustomobject] -and $requirement.PSObject.Properties['Id'] -and $requirement.Id -is [string]) { $requirement.Id } else { $null }
                if (-not $id) { $problems.Add("${file}: every requirement needs an Id written as a string."); continue }
                if (-not $seenIds.Add($id)) { $problems.Add("${file}: the requirement $id is listed more than once."); continue }

                $related = [System.Collections.Generic.List[string]]::new()
                foreach ($reference in @($(if ($requirement.PSObject.Properties['Related']) { $requirement.Related }) | Where-Object { $null -ne $_ })) {
                    # A file holds the reference as a row carries it: the framework key in lowercase.
                    if ($reference -isnot [string] -or $reference -cnotmatch $controlPattern) {
                        $problems.Add("${file}: the requirement $id has the Related reference '$reference', which is not written <framework-key>:<control-id> with a lowercase key, for example nist-800-53-r5:IA-2(1).")
                        continue
                    }
                    $related.Add($reference)
                }
                $framework.ById[$id] = [pscustomobject]@{ Requirement = $requirement; Related = $related.ToArray() }
            }
        }

        $framework.IsValid = $problems.Count -eq 0
        $framework
    }
}

function Get-MtFrameworkIndex {
    <#
    .SYNOPSIS
    Returns the frameworks a Control can refer to, by key.

    .DESCRIPTION
    A Control names a framework by its key, whatever suite declares it: a test of the Maester suite can refer
    to cisa-scuba. The index holds the frameworks of every suite.json under -Root, the frameworks passed with
    -Framework (those of the suites already read) and, unless -BuiltIn, the frameworks shipped with Maester
    (Get-MtBuiltInFramework).

    Returns ByKey (framework key to framework, valid or not), All (every framework found under -Root or passed
    in), Problems and Unresolved (filled by Complete-MtNativeTest). A key that two suites declare is a problem
    that names both suite.json files; the first one keeps the key: a shipped framework before a custom one,
    then in the order of the paths.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Folders that are searched for suite.json files.
        [Parameter()] [AllowEmptyCollection()] [string[]] $Root = @(),

        # Frameworks that are already loaded (Get-MtLoadedFramework).
        [Parameter()] [AllowEmptyCollection()] [object[]] $Framework = @(),

        # The suite.json files read so far (Get-MtSuiteManifest), so that none is read twice.
        [Parameter()] [hashtable] $Cache = @{},

        # The roots hold the tests shipped with Maester: their Custom folder is skipped and nothing else is added.
        [Parameter()] [switch] $BuiltIn
    )

    $found = [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    foreach ($folder in $Root) {
        if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        $rootFull = (Resolve-Path -LiteralPath $folder).Path
        $customPrefix = (Join-Path $rootFull 'custom') + [System.IO.Path]::DirectorySeparatorChar
        foreach ($manifest in (Get-ChildItem -LiteralPath $rootFull -Filter 'suite.json' -Recurse -File -ErrorAction SilentlyContinue)) {
            if ($BuiltIn -and $manifest.FullName.StartsWith($customPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            foreach ($loaded in @(Get-MtLoadedFramework -Suite (Get-MtSuiteManifest -File $manifest.FullName -Root $rootFull -Cache $Cache))) { $null = $found.Add($loaded) }
        }
    }
    foreach ($loaded in $Framework) { if ($loaded) { $null = $found.Add($loaded) } }
    $all = @($found | Sort-Object -Property SuiteFile -Stable)

    $byKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @($(if (-not $BuiltIn) { Get-MtBuiltInFramework })) + $all) {
        # A framework whose key is not a key has no file.
        if (-not $candidate.File) { continue }
        $existing = $null
        if (-not $byKey.TryGetValue($candidate.Key, [ref] $existing)) { $byKey[$candidate.Key] = $candidate; continue }
        # The same suite.json again, or a key it declares twice, which is a problem of that suite.json.
        if ([string]::Equals($existing.SuiteFile, $candidate.SuiteFile, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $problems.Add("$($candidate.SuiteFile): the framework '$($candidate.Key)' is also declared by '$($existing.SuiteFile)'. A framework key is declared by one suite; the first one is used.")
    }
    [pscustomobject]@{
        ByKey      = $byKey
        All        = $all
        Problems   = $problems
        Unresolved = [System.Collections.Generic.List[object]]::new()
    }
}

function Get-MtBuiltInFramework {
    <#
    .SYNOPSIS
    Returns the frameworks of the suites shipped with Maester. Read once for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ($null -eq $script:__MtBuiltInFramework) {
        $root = Get-MtMaesterTestFolderPath
        # The build checks these files, so a run does not warn about them.
        $script:__MtBuiltInFramework = @(if (Test-Path -LiteralPath $root -PathType Container) { (Get-MtFrameworkIndex -Root $root -BuiltIn -WarningAction SilentlyContinue).ByKey.Values })
    }
    $script:__MtBuiltInFramework
}

function Resolve-MtTestBenchmark {
    <#
    .SYNOPSIS
    Returns the Benchmark of a test and the Related references of the requirements its Control names.

    .DESCRIPTION
    A Control value is <framework-key>:<id>. When the key is a framework of the index and the id is a
    requirement of its file, the reference resolves. Benchmark comes from the first reference that resolves,
    in the order of the attribute: Framework, Version and Requirement, followed by every other fact of the
    requirement, such as Level and Profile, or Criticality and Upstream. Id, Related and Tests are not copied.
    Related holds the Related references of every requirement that resolved, to be added to the test's Control.

    Benchmark is $null when no reference resolves. A reference to a framework the index does not have, or to
    one with problems, is left as it is. Unresolved lists the references that name a valid framework and a
    requirement its file does not have, each with Reference and Framework.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The Control values of the test.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [string[]] $Control,

        # The frameworks a Control can refer to (Get-MtFrameworkIndex).
        [Parameter(Mandatory)] [object] $Index
    )

    $benchmark = $null
    $related = [System.Collections.Generic.List[string]]::new()
    $unresolved = [System.Collections.Generic.List[object]]::new()
    foreach ($reference in @($Control | Where-Object { $_ })) {
        $key, $id = $reference -split ':', 2
        $framework = $null
        if (-not $id -or -not $Index.ByKey.TryGetValue($key, [ref] $framework) -or -not $framework.IsValid) { continue }
        $entry = $null
        if (-not $framework.ById.TryGetValue($id, [ref] $entry)) {
            $unresolved.Add([pscustomobject]@{ Reference = $reference; Framework = $framework })
            continue
        }
        if (-not $benchmark) {
            $benchmark = [ordered]@{ Framework = $framework.Key; Version = $framework.Version; Requirement = [string]$entry.Requirement.Id }
            foreach ($fact in $entry.Requirement.PSObject.Properties) {
                if ($fact.Name -in 'Id', 'Tests', 'Related' -or $benchmark.Contains($fact.Name)) { continue }
                $benchmark[$fact.Name] = $fact.Value
            }
        }
        $related.AddRange([string[]]$entry.Related)
    }
    [pscustomobject]@{
        Benchmark  = if ($benchmark) { [pscustomobject]$benchmark } else { $null }
        Related    = $related.ToArray()
        Unresolved = $unresolved.ToArray()
    }
}

function Get-MtFrameworkProblem {
    <#
    .SYNOPSIS
    Returns one message for each thing that is wrong with the framework files of the suites under a folder.

    .DESCRIPTION
    Used by the catalog build, which fails on any message, and by the unit tests. It returns:

    - the problems of each declaration and file (Get-MtSuiteFramework), also of a suite that has no test;
    - a framework key that two suites declare (Get-MtFrameworkIndex);
    - a test whose Control names one of these frameworks and a requirement its file does not have.

    A Control that names a framework no suite under the folder declares is not checked. Each message starts
    with the path of a file and names the key or the ID.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The tests under the root (Get-MtNativeTestInventory).
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Test,

        # The folder that holds the suites.
        [Parameter(Mandatory)] [string] $Root
    )

    $index = Get-MtFrameworkIndex -Root $Root -BuiltIn -WarningAction SilentlyContinue
    foreach ($framework in $index.All) { $framework.Problems }
    $index.Problems
    foreach ($t in $Test) {
        if (-not $t.Id) { continue }
        foreach ($miss in (Resolve-MtTestBenchmark -Control $t.Control -Index $index).Unresolved) {
            "$($t.File): the test $($t.Id) has the Control '$($miss.Reference)', and '$($miss.Framework.File)' has no requirement with that Id."
        }
    }
}

function Get-MtLoadedFramework {

    <#
    .SYNOPSIS
    Returns the frameworks that Get-MtSuiteManifest loaded for a suite.json, or nothing.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [AllowNull()] [object] $Suite
    )

    if ($Suite -is [pscustomobject] -and $Suite.PSObject.Properties['LoadedFrameworks']) { $Suite.LoadedFrameworks }
}

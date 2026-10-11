function Get-MtSuiteFramework {
    <#
    .SYNOPSIS
    Reads the frameworks a suite.json declares and their framework files (test attribute design, section 6).

    .DESCRIPTION
    A suite that implements a published benchmark says so in its suite.json:

        "Frameworks": [ { "Key": "cis-m365", "Version": "7.0.0", "IdPrefix": "CIS.M365." } ]

    The facts about each requirement are in frameworks/<Key>.json beside the suite.json: Framework (the key),
    Name, Version and Requirements, each with an Id, the Tests that implement it, optional Related references
    to controls of other frameworks, and any other fact, such as Level or Criticality.

    Returns one object per declared framework: Key, Version, IdPrefix, Name, Url, SuiteFile, File,
    Requirements (the entries of the file), ByTest (test ID to its requirement and Related references,
    case-insensitive), Unlisted (filled by Resolve-MtTestBenchmark), Problems and IsValid.

    Nothing is thrown. Problems lists what is wrong with the declaration or the file, each message starting
    with the path of the file. A run warns about a framework with problems and gives its tests no Benchmark;
    the catalog build fails on them (Get-MtFrameworkProblem). Each file is read once per call.
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
    $seenPrefixes = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)

    foreach ($entry in @($Suite.Frameworks | Where-Object { $null -ne $_ })) {
        $problems = [System.Collections.Generic.List[string]]::new()
        $read = { param($name) if ($entry -is [pscustomobject] -and $entry.PSObject.Properties[$name] -and $null -ne $entry.$name) { [string]$entry.$name } else { $null } }
        $framework = [pscustomobject]@{
            Key          = & $read 'Key'
            Version      = & $read 'Version'
            IdPrefix     = & $read 'IdPrefix'
            Name         = $null
            Url          = $null
            SuiteFile    = $suiteFile
            File         = $null
            Requirements = @()
            ByTest       = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
            Unlisted     = [System.Collections.Generic.List[string]]::new()
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
        if (-not $framework.IdPrefix) { $problems.Add("${suiteFile}: the framework '$($framework.Key)' has no IdPrefix.") }
        elseif (-not $seenPrefixes.Add($framework.IdPrefix)) { $problems.Add("${suiteFile}: the IdPrefix '$($framework.IdPrefix)' of the framework '$($framework.Key)' is used by another framework of the suite.") }

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
            $listedIn = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new($ignoreCase)
            foreach ($requirement in $requirements) {
                # An ID such as 1.10 written as a number would be read as 1.1.
                $id = if ($requirement -is [pscustomobject] -and $requirement.PSObject.Properties['Id'] -and $requirement.Id -is [string]) { $requirement.Id } else { $null }
                if (-not $id) { $problems.Add("${file}: every requirement needs an Id written as a string."); continue }
                if (-not $seenIds.Add($id)) { $problems.Add("${file}: the requirement $id is listed more than once.") }

                $related = [System.Collections.Generic.List[string]]::new()
                foreach ($reference in @($(if ($requirement.PSObject.Properties['Related']) { $requirement.Related }) | Where-Object { $null -ne $_ })) {
                    # A file holds the reference as a row carries it: the framework key in lowercase.
                    if ($reference -isnot [string] -or $reference -cnotmatch $controlPattern) {
                        $problems.Add("${file}: the requirement $id has the Related reference '$reference', which is not written <framework-key>:<control-id> with a lowercase key, for example nist-800-53-r5:IA-2(1).")
                        continue
                    }
                    $related.Add($reference)
                }

                foreach ($testId in @($(if ($requirement.PSObject.Properties['Tests']) { $requirement.Tests }) | Where-Object { $null -ne $_ })) {
                    if ($testId -isnot [string] -or -not $testId) { $problems.Add("${file}: the requirement $id has a Tests entry that is not a test ID."); continue }
                    if (-not $listedIn.ContainsKey($testId)) { $listedIn[$testId] = [System.Collections.Generic.List[string]]::new() }
                    $listedIn[$testId].Add($id)
                    $framework.ByTest[$testId] = [pscustomobject]@{ Requirement = $requirement; Related = $related.ToArray() }
                }
            }
            foreach ($testId in $listedIn.Keys) {
                if ($listedIn[$testId].Count -gt 1) {
                    $problems.Add("${file}: the test $testId is listed $($listedIn[$testId].Count) times (requirements $($listedIn[$testId] -join ', ')). A test is listed once.")
                }
            }
        }

        $framework.IsValid = $problems.Count -eq 0
        $framework
    }
}

function Resolve-MtTestBenchmark {
    <#
    .SYNOPSIS
    Returns the Benchmark of a test and the Related references of its requirement, or $null.

    .DESCRIPTION
    The test belongs to the framework of its suite whose IdPrefix its ID starts with; the longest prefix wins
    when several match. Benchmark is Framework, Version and Requirement (the Id of the requirement that lists
    the test), followed by every other fact of that requirement, such as Level and Profile, or Criticality and
    Upstream. Id, Tests and Related are not copied: Related is returned beside it, to be added to the test's
    Control.

    Returns $null when no prefix matches, when the framework has problems, and when its file does not list the
    test. In the last case the ID is added to the framework's Unlisted, so the caller can warn once.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Id,

        # The frameworks of the test's suite (Get-MtSuiteFramework).
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Framework
    )

    $match = Select-MtTestFramework -Id $Id -Framework $Framework
    if (-not $match -or -not $match.IsValid) { return $null }
    $entry = $null
    if (-not $match.ByTest.TryGetValue($Id, [ref] $entry)) { $match.Unlisted.Add($Id); return $null }

    $benchmark = [ordered]@{ Framework = $match.Key; Version = $match.Version; Requirement = [string]$entry.Requirement.Id }
    foreach ($fact in $entry.Requirement.PSObject.Properties) {
        if ($fact.Name -in 'Id', 'Tests', 'Related' -or $benchmark.Contains($fact.Name)) { continue }
        $benchmark[$fact.Name] = $fact.Value
    }
    [pscustomobject]@{ Benchmark = [pscustomobject]$benchmark; Related = $entry.Related }
}

function Select-MtTestFramework {
    <#
    .SYNOPSIS
    Returns the framework whose IdPrefix a test ID starts with: the longest prefix when several match, else $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Id,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Framework
    )

    $match = $null
    foreach ($candidate in $Framework) {
        if (-not $candidate.IdPrefix -or -not $Id.StartsWith($candidate.IdPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not $match -or $candidate.IdPrefix.Length -gt $match.IdPrefix.Length) { $match = $candidate }
    }
    $match
}

function Get-MtFrameworkProblem {
    <#
    .SYNOPSIS
    Returns one message for each thing that is wrong with the framework files of the suites under a folder.

    .DESCRIPTION
    Used by the catalog build, which fails on any message, and by the unit tests. Beside the problems of each
    declaration and file (Get-MtSuiteFramework), it checks what needs the tests of the suite:

    - every test a framework file names is a test of the suite, and its ID starts with the framework's IdPrefix;
    - every test of the suite whose ID has the prefix is listed in the file. A test listed more than once is a
      problem of the file.

    A test belongs to the nearest suite.json above it. Each message starts with the path of the file and names
    the ID.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The tests under the root (Get-MtNativeTestInventory).
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Test,

        # The folder that holds the suites.
        [Parameter(Mandatory)] [string] $Root
    )

    $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
    $cache = @{}
    $rootFull = (Resolve-Path -LiteralPath $Root).Path
    $customPrefix = (Join-Path $rootFull 'custom') + [System.IO.Path]::DirectorySeparatorChar

    # The frameworks of every suite, also of a suite that has no test.
    $frameworks = [System.Collections.Generic.List[object]]::new()
    $testsOf = @{}
    foreach ($manifest in (Get-ChildItem -LiteralPath $rootFull -Filter 'suite.json' -Recurse -File | Sort-Object FullName)) {
        if ($manifest.FullName.StartsWith($customPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $suite = Get-MtSuiteManifest -File $manifest.FullName -Root $rootFull -Cache $cache -WarningAction SilentlyContinue
        foreach ($framework in @(Get-MtLoadedFramework -Suite $suite)) {
            $frameworks.Add($framework)
            $testsOf[$framework.SuiteFile] = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
        }
    }
    foreach ($t in $Test) {
        if (-not $t.Id -or -not $t.File) { continue }
        $suite = Get-MtSuiteManifest -File $t.File -Root $rootFull -Cache $cache -WarningAction SilentlyContinue
        $declared = @(Get-MtLoadedFramework -Suite $suite)
        if ($declared.Count -gt 0 -and $testsOf.ContainsKey($declared[0].SuiteFile)) { $null = $testsOf[$declared[0].SuiteFile].Add([string]$t.Id) }
    }

    foreach ($framework in $frameworks) {
        $framework.Problems
        if (-not $framework.IsValid) { continue }
        $suiteTests = $testsOf[$framework.SuiteFile]
        $siblings = @($frameworks | Where-Object { $_.SuiteFile -eq $framework.SuiteFile })
        foreach ($requirement in $framework.Requirements) {
            foreach ($testId in @($(if ($requirement.PSObject.Properties['Tests']) { $requirement.Tests }))) {
                if (-not $suiteTests.Contains($testId)) {
                    "$($framework.File): the requirement $($requirement.Id) names the test $testId, which is not a test of the suite."
                } elseif (-not $testId.StartsWith($framework.IdPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    "$($framework.File): the requirement $($requirement.Id) names the test $testId, whose ID does not start with the IdPrefix '$($framework.IdPrefix)'."
                }
            }
        }
        foreach ($testId in ($suiteTests | Sort-Object)) {
            if ($framework.ByTest.ContainsKey($testId)) { continue }
            if ([object]::ReferenceEquals((Select-MtTestFramework -Id $testId -Framework $siblings), $framework)) {
                "$($framework.File): the test $testId has the IdPrefix '$($framework.IdPrefix)' and is not listed in a requirement. Every test with the prefix is listed once."
            }
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

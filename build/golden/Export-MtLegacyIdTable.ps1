<#
    .SYNOPSIS
    Generates the Maester previous-ID table (Maester.LegacyIds.json) from the git history of tests/.

    .DESCRIPTION
    Walks every commit that touched a *.Tests.ps1 file under tests/ (tests/Custom excluded), parses the
    It names of every changed file version with the PowerShell AST (regex fallback for files that do
    not parse) and records every static test ID that ever shipped.

    The ID of an It name is the text before the first colon when that text has no spaces
    (for example 'MT.1001' or 'MS.AAD.7.1'). Early wrappers had no ID; for those the whole It name is
    recorded as the legacy ID. Templated names (containing '<' or '$(') are skipped: family wrappers
    are matched by prefix (FamilyPrefixes) at runtime.

    Every historical ID that is not a current ID is mapped to its current ID, or to 'retired':
      manual   - the ID is listed in $ManualOverrides below
      prefix   - a known prefix rename (for example 'MS.' -> 'CISA.MS.') yields a current ID
      title    - a historical title (text after the colon, normalised) equals the title of exactly one current test
      function - the single check function called in the It body is called by exactly one current test
      retired  - nothing matched

    The output is deterministic: GeneratedFrom is the last commit that touched the scanned test files,
    and current IDs are read from that commit's tree, so rerunning on a later commit that does not touch
    tests/ produces identical output.

    .EXAMPLE
    ./build/golden/Export-MtLegacyIdTable.ps1

    Regenerates powershell/assets/Maester.LegacyIds.json.

    .EXAMPLE
    ./build/golden/Export-MtLegacyIdTable.ps1 -WhatIf -Verbose

    Prints the review report (ambiguous and title-only matches) without writing the file.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    # Root of the Maester repository.
    [string] $RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path,

    # Output path for the generated table.
    [string] $OutputPath = "$PSScriptRoot/../../powershell/assets/Maester.LegacyIds.json"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -Path $RepoRoot).Path

#region Manual overrides
# Reviewed by hand. Value is a current ID or 'retired'. Applied before every automatic rule.
$ManualOverrides = [ordered]@{
    # The original combined high-risk app permission check, later split into MT.1050 (direct) and MT.1051 (indirect).
    'Ensure no graph application has permissions with a risk of having a direct or indirect path to Global Admin and full tenant takeover.' = 'MT.1050'
    'MT.1050 Apps with high-risk permissions having a direct or indirect path to Global Admin'                                    = 'MT.1050'
    # Pre-colon names of the split checks; the current titles say 'Global Administrator' and both call one function.
    'MT.1050 Apps with high-risk permissions having a direct path to Global Admin'                                                = 'MT.1050'
    'MT.1051 Apps with high-risk permissions having an indirect path to Global Admin'                                             = 'MT.1051'
    # Mock-based unit tests that briefly lived under tests/; they were never security checks.
    'MFA for All users should pass even if not targeting guests'                                                                   = 'retired'
    'MFA for All users that excludes any guest type should fail'                                                                   = 'retired'
    'MFA for Guests should pass'                                                                                                   = 'retired'
    'MFA for Guests that excludes any guest type should fail'                                                                      = 'retired'
    'Policy without non persistent browser session should fail'                                                                    = 'retired'
}
#endregion Manual overrides

# Historical IDs too generic to identify a Maester test: a user's own test could use them ('EIDSCA: ...'),
# and a listed ID makes Maester skip, and Update-MaesterTests delete, such a test. Left out of the table.
# AADSC and EIDSCA were shared by every check of the early generated files; Exclude and Include were
# mock-based unit tests that briefly lived under tests/.
$GenericIds = @('AADSC', 'EIDSCA', 'Exclude', 'Include')

# Known prefix renames, applied in order: old prefix -> new prefix.
$PrefixRenames = @(
    @{ Old = 'MS.'; New = 'CISA.MS.' }   # CISA checks before the CISA. prefix
    @{ Old = 'ID10'; New = 'MT.10' }     # first Maester checks: ID1001 -> MT.1001
    @{ Old = 'MT10'; New = 'MT.10' }     # then MT1001 -> MT.1001
)

# Commands that are not check functions.
$IgnoredFunctions = @('Test-Path', 'Test-Json', 'Test-Connection', 'Test-NetConnection', 'Test-MtConnection', 'Test-MtContext')

$testPathSpec = @(':(glob,icase)tests/**/*.tests.ps1', ':(exclude,glob,icase)tests/Custom/**')

function Invoke-Git {
    # Arguments are passed through $args so git switches such as -p are not bound as PowerShell parameters.
    $output = & git -C $RepoRoot @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
    return $output
}

function Get-NormalizedTitle {
    param([string] $Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return '' }
    $t = ($Title -replace '\s+', ' ').Trim().ToLowerInvariant()
    $t = $t -replace '[\s\.]+$', ''
    $t = $t -replace '\.? *see https?://\S+$', ''
    $t = $t -replace '^\(l\d\)\s*', ''
    return $t.Trim()
}

function Split-ItName {
    # Returns @{ Id; Title; HasId } for an It name. Without an ID before a colon, the whole name is the ID
    # and the title used for matching drops a leading ID-like token ('MT.1038 ', 'MT. ', 'CIS 1.1.1 ').
    param([string] $Name)
    $name = ($Name -replace '\s+', ' ').Trim()
    $colon = $name.IndexOf(':')
    if ($colon -gt 0) {
        $candidate = $name.Substring(0, $colon).Trim()
        if ($candidate -match '^[A-Za-z0-9][A-Za-z0-9._\-]*$') {
            return @{ Id = $candidate; Title = $name.Substring($colon + 1).Trim(); HasId = $true }
        }
    }
    $title = $name -replace '^(MT\.\d*|CIS \d+(\.\d+)*|\d+(\.\d+)+)\s+', ''
    return @{ Id = $name; Title = $title; HasId = $false }
}

function Get-ItNameFromAst {
    param([System.Management.Automation.Language.CommandAst] $Command)
    $elements = $Command.CommandElements
    $nameAst = $null
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $element = $elements[$i]
        if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            if ($element.ParameterName -eq 'Name') {
                $nameAst = if ($element.Argument) { $element.Argument } else { $elements[$i + 1] }
                break
            }
            if (-not $element.Argument -and $element.ParameterName -notin 'Skip', 'Pending', 'Focus') { $i++ }
            continue
        }
        $nameAst = $element
        break
    }
    if ($nameAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $nameAst.Value }
    if ($nameAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        if ($nameAst.NestedExpressions.Count -eq 0) { return $nameAst.Value }
        return $nameAst.Extent.Text.Trim('"')  # templated; caller skips it
    }
    return $null
}

function Get-ItInfo {
    # Parses test file content and returns one object per It name.
    param([string] $Content)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref] $tokens, [ref] $parseErrors)
    $results = [System.Collections.Generic.List[object]]::new()
    if ($parseErrors.Count -eq 0) {
        $commands = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'It'
            }, $true)
        foreach ($command in $commands) {
            $name = Get-ItNameFromAst -Command $command
            if (-not $name) { continue }
            $body = $command.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -Last 1
            $functions = @()
            if ($body) {
                $functions = @($body.FindAll({
                            param($node)
                            $node -is [System.Management.Automation.Language.CommandAst]
                        }, $true) | ForEach-Object { $_.GetCommandName() } |
                        Where-Object { $_ -like 'Test-*' -and $_ -notin $IgnoredFunctions } | Sort-Object -Unique)
            }
            $results.Add([pscustomobject]@{ Name = $name; Functions = $functions })
        }
    } else {
        foreach ($match in [regex]::Matches($Content, '(?m)^\s*It\s+([''"])(.+?)\1')) {
            $results.Add([pscustomobject]@{ Name = $match.Groups[2].Value; Functions = @() })
        }
    }
    return $results
}

function Test-TemplatedName {
    param([string] $Name)
    return ($Name.Contains('<') -or $Name.Contains('$'))
}

function Get-StaticSplit {
    # Returns the Split-ItName result when the ID part of the name is static, otherwise $null.
    # 'MT.1024: Emergency access users should not be blocked (<userPrincipalName>)' has the static ID MT.1024.
    param([string] $Name)
    $split = Split-ItName -Name $Name
    if (-not (Test-TemplatedName $Name)) { return $split }
    if ($split.HasId -and -not (Test-TemplatedName $split.Id)) { return $split }
    return $null
}

#region Scan history
$logLines = Invoke-Git log --reverse --no-renames --raw --no-abbrev --format='commit %H' -- @testPathSpec
$commits = [System.Collections.Generic.List[object]]::new()
$current = $null
foreach ($line in $logLines) {
    if ($line -match '^commit ([0-9a-f]{40})$') {
        $current = [pscustomobject]@{ Sha = $Matches[1]; Files = [System.Collections.Generic.List[object]]::new() }
        $commits.Add($current)
    } elseif ($line -match '^:\d+ \d+ [0-9a-f]+ ([0-9a-f]{40}) ([AMT])\t(.+)$') {
        $current.Files.Add([pscustomobject]@{ Blob = $Matches[1]; Path = $Matches[3] })
    }
}
$commits = @($commits | Where-Object { $_.Files.Count -gt 0 })
if ($commits.Count -eq 0) { throw 'No commits found that touched tests/*.Tests.ps1.' }
$generatedFrom = $commits[-1].Sha
Write-Verbose "Scanning $($commits.Count) commits; last is $generatedFrom"

$blobCache = @{}
function Get-BlobItInfo {
    param([string] $Blob)
    if (-not $blobCache.ContainsKey($Blob)) {
        $content = (Invoke-Git cat-file -p $Blob) -join "`n"
        $blobCache[$Blob] = Get-ItInfo -Content $content
    }
    return $blobCache[$Blob]
}

# Historical IDs: Id -> record
$history = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$historicalFamilies = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($commit in $commits) {
    foreach ($file in $commit.Files) {
        foreach ($it in (Get-BlobItInfo -Blob $file.Blob)) {
            $split = Get-StaticSplit -Name $it.Name
            if (-not $split) {
                if ($it.Name -match '^([A-Za-z]+\.?\d+)\.(<|\$\()') { $null = $historicalFamilies.Add("$($Matches[1]).") }
                continue
            }
            if (-not $history.ContainsKey($split.Id)) {
                $history[$split.Id] = [pscustomobject]@{
                    Id = $split.Id; FirstSeenCommit = $commit.Sha
                    Titles = [System.Collections.Generic.HashSet[string]]::new(); Functions = [System.Collections.Generic.HashSet[string]]::new()
                    LastSeenCommit = $null; LastSeenFile = $null
                }
            }
            $record = $history[$split.Id]
            $record.LastSeenCommit = $commit.Sha
            $record.LastSeenFile = $file.Path
            $null = $record.Titles.Add((Get-NormalizedTitle $split.Title))
            foreach ($f in $it.Functions) { $null = $record.Functions.Add($f) }
        }
    }
}
#endregion Scan history

#region Current IDs (from the tree of $generatedFrom)
$currentIds = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$familyPrefixes = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
$treeLines = Invoke-Git ls-tree -r $generatedFrom -- tests
foreach ($line in $treeLines) {
    if ($line -notmatch '^\d+ blob ([0-9a-f]{40})\t(tests/.+\.tests\.ps1)$') { continue }
    if ($Matches[2] -like 'tests/Custom/*') { continue }
    $path = $Matches[2]
    foreach ($it in (Get-BlobItInfo -Blob $Matches[1])) {
        $split = Get-StaticSplit -Name $it.Name
        if (-not $split) {
            if ($it.Name -match '^([A-Za-z]+\.?\d+)\.(<|\$\()') { $null = $familyPrefixes.Add("$($Matches[1]).") }
            continue
        }
        $currentIds[$split.Id] = [pscustomobject]@{ Id = $split.Id; Title = (Get-NormalizedTitle $split.Title); Functions = $it.Functions; Path = $path }
    }
}
Write-Verbose "Current static IDs: $($currentIds.Count); family prefixes: $($familyPrefixes -join ', ')"

$titleIndex = @{}
$functionIndex = @{}
foreach ($c in $currentIds.Values) {
    if (-not $titleIndex.ContainsKey($c.Title)) { $titleIndex[$c.Title] = [System.Collections.Generic.SortedSet[string]]::new() }
    $null = $titleIndex[$c.Title].Add($c.Id)
    if ($c.Functions.Count -eq 1) {
        $f = $c.Functions[0]
        if (-not $functionIndex.ContainsKey($f)) { $functionIndex[$f] = [System.Collections.Generic.SortedSet[string]]::new() }
        $null = $functionIndex[$f].Add($c.Id)
    }
}
#endregion Current IDs

#region Map
$entries = [System.Collections.Generic.List[object]]::new()
$review = [System.Collections.Generic.List[string]]::new()
foreach ($record in $history.Values) {
    if ($currentIds.ContainsKey($record.Id)) { continue }
    if ($record.Id -in $GenericIds) { continue }

    $titleCandidates = [System.Collections.Generic.SortedSet[string]]::new()
    foreach ($t in $record.Titles) { if ($t -and $titleIndex.ContainsKey($t)) { $titleCandidates.UnionWith($titleIndex[$t]) } }
    $functionCandidates = [System.Collections.Generic.SortedSet[string]]::new()
    if ($record.Functions.Count -eq 1) {
        $f = @($record.Functions)[0]
        if ($functionIndex.ContainsKey($f)) { $functionCandidates.UnionWith($functionIndex[$f]) }
    }
    $prefixTarget = $null
    foreach ($rename in $PrefixRenames) {
        if ($record.Id.StartsWith($rename.Old, [System.StringComparison]::OrdinalIgnoreCase)) {
            $target = $rename.New + $record.Id.Substring($rename.Old.Length)
            if ($currentIds.ContainsKey($target)) { $prefixTarget = $currentIds[$target].Id; break }
        }
    }

    $currentId = 'retired'; $rule = 'retired'
    if ($ManualOverrides.Contains($record.Id)) {
        $currentId = $ManualOverrides[$record.Id]; $rule = 'manual'
    } elseif ($prefixTarget) {
        $currentId = $prefixTarget; $rule = 'prefix'
    } elseif ($titleCandidates.Count -eq 1) {
        $currentId = @($titleCandidates)[0]; $rule = 'title'
        if ($functionCandidates.Count -gt 0 -and -not $functionCandidates.Contains($currentId)) {
            $review.Add("CONFLICT  $($record.Id): title -> $currentId, function -> $($functionCandidates -join '|')")
        } elseif ($functionCandidates.Count -eq 0) {
            $review.Add("TITLEONLY $($record.Id) -> $currentId (functions: $(@($record.Functions) -join '|'))")
        }
    } elseif ($titleCandidates.Count -gt 1) {
        $narrowed = @($titleCandidates | Where-Object { $functionCandidates.Contains($_) })
        if ($narrowed.Count -eq 1) {
            $currentId = $narrowed[0]; $rule = 'function'
        } else {
            $review.Add("AMBIGUOUS $($record.Id): title -> $($titleCandidates -join '|'), function -> $($functionCandidates -join '|')")
        }
    } elseif ($functionCandidates.Count -eq 1) {
        $currentId = @($functionCandidates)[0]; $rule = 'function'
    } elseif ($functionCandidates.Count -gt 1) {
        $review.Add("AMBIGUOUS $($record.Id): function -> $($functionCandidates -join '|')")
    }

    if ($currentId -ne 'retired' -and -not $currentIds.ContainsKey($currentId)) {
        throw "Mapping for '$($record.Id)' targets '$currentId', which is not a current ID."
    }
    $entries.Add([ordered]@{
            LegacyId        = $record.Id
            CurrentId       = $currentId
            Rule            = $rule
            FirstSeenCommit = $record.FirstSeenCommit
            LastSeenCommit  = $record.LastSeenCommit
            LastSeenFile    = $record.LastSeenFile
        })
}
foreach ($key in $ManualOverrides.Keys) {
    if (-not ($entries | Where-Object { $_.LegacyId -eq $key })) { Write-Warning "Manual override '$key' did not match a historical ID." }
}
#endregion Map

#region Report
$sortedEntries = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::OrderBy([object[]]$entries.ToArray(), [Func[object, string]] { param($e) $e.LegacyId }, [System.StringComparer]::Ordinal))

Write-Verbose "Commits scanned: $($commits.Count)"
Write-Verbose "Historical static IDs: $($history.Count); legacy (not current): $($sortedEntries.Count)"
$sortedEntries | Group-Object { $_.Rule } | Sort-Object Name | ForEach-Object { Write-Verbose ("  {0,-8} {1}" -f $_.Name, $_.Count) }
$retiredFamilies = @($historicalFamilies | Where-Object { -not $familyPrefixes.Contains($_) })
if ($retiredFamilies) { Write-Warning "Historical family prefixes no longer at HEAD: $($retiredFamilies -join ', ')" }
foreach ($line in ($review | Sort-Object)) { Write-Verbose "REVIEW $line" }
#endregion Report

$document = [ordered]@{
    SchemaVersion  = '1.0'
    GeneratedFrom  = $generatedFrom
    Entries        = $sortedEntries
    FamilyPrefixes = @($familyPrefixes)
}
$json = ($document | ConvertTo-Json -Depth 5) -replace "`r`n", "`n"
if ($PSCmdlet.ShouldProcess($OutputPath, 'Write legacy ID table')) {
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutputPath), "$json`n", [System.Text.UTF8Encoding]::new($false))
}

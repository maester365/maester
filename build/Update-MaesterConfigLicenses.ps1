<#
.SYNOPSIS
    Populates the Licenses array on every TestSettings entry in tests/maester-config.json.

.DESCRIPTION
    Scans every Pester test (tests/**/*.Tests.ps1) and the PowerShell function it
    invokes (powershell/public|internal/...) for license signals, then writes the
    resulting Licenses array onto each matching TestSettings item by Id.

    Signals (multiple matches union):
      1. Add-MtTestResultDetail -SkippedBecause NotLicensed<Token>
      2. Get-MtLicenseInformation -Product X comparisons
      3. -Skip:( ... license check ... ) on the It block
      4. Same patterns inside the underlying Test-* function
      5. License-bearing Describe/Context/It tags
      6. Explicit license-requirement statements in the website doc and in the
         function's companion .md (e.g. "Microsoft Entra ID P1 or P2 is required")

    Defaults when no signal is found:
      - AZDO.* tests                   -> ["AzureDevOps"]
      - Config Id with no backing test -> ["TBD"]   (true orphan)
      - Test exists, no premium signal -> []        (baseline is adequate)

    The script is idempotent: re-running replaces an existing Licenses field
    in-place rather than appending a duplicate key.

.PARAMETER DryRun
    Print the per-test license map and a tally; do not write to maester-config.json.

.EXAMPLE
    pwsh build/Update-MaesterConfigLicenses.ps1 -DryRun
    pwsh build/Update-MaesterConfigLicenses.ps1
#>
[CmdletBinding()]
param(
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$testsRoot = Join-Path $repoRoot 'tests'
$psPublicRoot = Join-Path $repoRoot 'powershell/public'
$psInternalRoot = Join-Path $repoRoot 'powershell/internal'
$docsRoot = Join-Path $repoRoot 'website/docs/tests'
$configPath = Join-Path $testsRoot 'maester-config.json'

# --- Token vocabulary (kept in sync with Get-MtLicenseInformation.ps1 + Get-MtSkippedReason.ps1) ---
$canonicalTokens = @(
    'EntraIDP1', 'EntraIDP2', 'EntraIDGovernance',
    'EntraWorkloadIDP1', 'EntraWorkloadIDP2',
    'Eop', 'MdoP1', 'MdoP2',
    'ExoDlp', 'AdvAudit', 'DefenderXDR',
    'Intune', 'CustomerLockbox',
    'AzureDevOps', 'TBD'
)

# Map NotLicensed<Suffix> -> token. Mdo (no plan) is treated as MdoP2 because the
# skip text in Get-MtSkippedReason.ps1 references "Defender for Office 365 Plan 2".
$skipReasonMap = @{
    'NotLicensedEntraIDP1'         = 'EntraIDP1'
    'NotLicensedEntraIDP2'         = 'EntraIDP2'
    'NotLicensedEntraIDGovernance' = 'EntraIDGovernance'
    'NotLicensedEntraWorkloadID'   = 'EntraWorkloadIDP1'
    'NotLicensedEop'               = 'Eop'
    'NotLicensedExoDlp'            = 'ExoDlp'
    'NotLicensedMdo'               = 'MdoP2'
    'NotLicensedMdoP1'             = 'MdoP1'
    'NotLicensedMdoP2'             = 'MdoP2'
    'NotLicensedAdvAudit'          = 'AdvAudit'
    'NotLicensedDefenderXDR'       = 'DefenderXDR'
    'NotLicensedIntune'            = 'Intune'
    'NotLicensedCustomerLockbox'   = 'CustomerLockbox'
}

# Describe/Context/It tag -> token (case-insensitive match against trimmed tag).
# 'entra id free' is intentionally unmapped: an explicit baseline tag yields the
# same '[]' as the no-signal default, so no entry is needed.
$tagMap = @{
    'entra id p1'     = 'EntraIDP1'
    'entra id p2'     = 'EntraIDP2'
    'governance'      = 'EntraIDGovernance'
    'defenderxdr'     = 'DefenderXDR'
    'intune'          = 'Intune'
    'mdi'             = 'DefenderXDR'
    'customerlockbox' = 'CustomerLockbox'
    'mdop1'           = 'MdoP1'
    'mdop2'           = 'MdoP2'
}

# Markdown free-text phrase -> token. Scanned in remediation/overview prose of
# website/docs/tests/<id>.md and the companion <function>.md beside the test
# function. Catches license claims that aren't reflected in code (e.g. a doc
# that says "Microsoft Entra ID P1 or P2 is required" but the code doesn't gate).
$markdownPhraseMap = [ordered]@{
    'entra id p2 license'                    = 'EntraIDP2'
    'entra id p1 license'                    = 'EntraIDP1'
    'entra id p1 or p2'                      = 'EntraIDP1'
    'entra id p2'                            = 'EntraIDP2'
    'entra id p1'                            = 'EntraIDP1'
    'entra id governance'                    = 'EntraIDGovernance'
    'aad premium p2'                         = 'EntraIDP2'
    'aad premium p1'                         = 'EntraIDP1'
    'azure ad premium p2'                    = 'EntraIDP2'
    'azure ad premium p1'                    = 'EntraIDP1'
    'workload identities premium'            = 'EntraWorkloadIDP1'
}

# Test ID regex (matches website/scripts/generate-test-docs.mjs:231)
$idPattern = '(MT\.\d+|CIS\.[A-Za-z0-9.]+|CISA\.[A-Za-z0-9.]+|EIDSCA\.[A-Z0-9]+|ORCA\.\d+(?:\.\d+)?|AZDO\.\d+)'

function Get-LicenseTokensFromText {
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )
    $tokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    # Signal 1: Add-MtTestResultDetail -SkippedBecause NotLicensed<...>
    foreach ($m in [regex]::Matches($Text, '-SkippedBecause\s+(NotLicensed[A-Za-z0-9]+)')) {
        $reason = $m.Groups[1].Value
        if ($skipReasonMap.ContainsKey($reason)) {
            [void] $tokens.Add($skipReasonMap[$reason])
        }
    }

    # Signal 2: Get-MtLicenseInformation -Product X comparisons inside this scope.
    # Look at conditions paired with each Get-MtLicenseInformation call.
    foreach ($m in [regex]::Matches($Text, "Get-MtLicenseInformation\s+(?:-Product\s+)?['""]?([A-Za-z]+)['""]?\s*\)?\s*(-eq|-ne)\s*['""]([A-Za-z0-9]+)['""]")) {
        $product  = $m.Groups[1].Value
        $operator = $m.Groups[2].Value
        $value    = $m.Groups[3].Value

        switch ("$product/$operator/$value") {
            'EntraID/-ne/P2'         { [void] $tokens.Add('EntraIDP2'); break }
            'EntraID/-eq/P2'         { [void] $tokens.Add('EntraIDP2'); break }
            'EntraID/-ne/P1'         { [void] $tokens.Add('EntraIDP1'); break }
            'EntraID/-eq/Free'       { [void] $tokens.Add('EntraIDP1'); break }
            'EntraID/-ne/Free'       { break }  # Need P1+, but exact tier unknown; covered by signal 1 if present
            'EntraID/-eq/Governance' { [void] $tokens.Add('EntraIDGovernance'); break }
            default { }
        }
    }

    # Pattern: ($EntraIDPlan -eq 'Free') -> need P1+
    foreach ($m in [regex]::Matches($Text, "\$EntraIDPlan\s*-eq\s*['""](Free)['""]")) {
        [void] $tokens.Add('EntraIDP1')
    }
    # Pattern: ($EntraIDPlan -ne 'P2') -> need P2
    foreach ($m in [regex]::Matches($Text, "\$EntraIDPlan\s*-ne\s*['""]P2['""]")) {
        [void] $tokens.Add('EntraIDP2')
    }
    # Pattern: ($DefenderPlan -ne 'DefenderXDR') -> need DefenderXDR
    foreach ($m in [regex]::Matches($Text, "\$DefenderPlan\s*-ne\s*['""]DefenderXDR['""]")) {
        [void] $tokens.Add('DefenderXDR')
    }

    # Signal 5: License-bearing tags. Tags are quoted strings; we'll look for any of them.
    foreach ($pair in $tagMap.GetEnumerator()) {
        $tag = $pair.Key
        if ($Text -match "[""']\s*$([regex]::Escape($tag))\s*[""']") {
            [void] $tokens.Add($pair.Value)
        }
    }

    # Forward-compatible License:<Token> tag form.
    foreach ($m in [regex]::Matches($Text, "[""']License:([A-Za-z0-9]+)[""']")) {
        $candidate = $m.Groups[1].Value
        if ($canonicalTokens -contains $candidate) {
            [void] $tokens.Add($candidate)
        }
    }

    return @($tokens | Sort-Object)
}

function Get-MarkdownSignalsFromText {
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $tokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    # Strip the front-matter and the auto-generated "Test Metadata" section so we
    # only inspect prose. Those sections echo Pester Describe tags and would create
    # circular signal (markdown reflecting the same tag the code-signal already saw).
    $lines = $Text -split "`r?`n"
    $body = [System.Collections.Generic.List[string]]::new()
    $inFront = $false
    $skipBlock = $false
    foreach ($line in $lines) {
        if ($line -match '^---\s*$') { $inFront = -not $inFront; continue }
        if ($inFront) { continue }
        if ($line -match '^## Test Metadata') { $skipBlock = $true; continue }
        if ($skipBlock -and $line -match '^## ') { $skipBlock = $false }
        if ($skipBlock) { continue }
        $body.Add($line)
    }
    $prose = ($body -join "`n").ToLowerInvariant()

    foreach ($pair in $markdownPhraseMap.GetEnumerator()) {
        if ($prose.Contains($pair.Key)) { [void] $tokens.Add($pair.Value) }
    }
    return @($tokens | Sort-Object)
}

function Get-FunctionFileForTest {
    param(
        [Parameter(Mandatory)] [string] $TestFunctionName
    )
    foreach ($root in @($psPublicRoot, $psInternalRoot)) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Recurse -Filter "$TestFunctionName.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Get-MarkdownFileForId {
    param([Parameter(Mandatory)] [string] $Id)
    if (-not (Test-Path $docsRoot)) { return $null }
    $candidate = Get-ChildItem -Path $docsRoot -Recurse -Filter "$Id.md" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
    # Parent fallback (e.g. MT.1033.0 -> MT.1033.md, if it ever existed).
    $parent = $Id
    while ($parent -match '\.\d+$') {
        $parent = $parent -replace '\.\d+$', ''
        $candidate = Get-ChildItem -Path $docsRoot -Recurse -Filter "$parent.md" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    return $null
}

# --- Pass 1: parse every test file into per-test scope text ---

$testIndex = @{}  # testId -> @{ ItText, EnclosingText, FunctionName }

foreach ($file in Get-ChildItem -Path $testsRoot -Recurse -Filter '*.Tests.ps1' -File) {
    $content = Get-Content -Path $file.FullName -Raw
    if (-not $content) { continue }

    # Find every It block. We use a brace-counting walker because Pester It blocks contain {...}.
    $itMatches = [regex]::Matches($content, '(?ms)\bIt\s+["''](?<name>[^"'']+)["'']')
    foreach ($itMatch in $itMatches) {
        $itStart = $itMatch.Index
        $name = $itMatch.Groups['name'].Value

        # Resolve testId
        $idMatch = [regex]::Match($name, "^${idPattern}:")
        $id = $null
        if ($idMatch.Success) { $id = $idMatch.Groups[1].Value }

        # Walk forward to find the matching closing brace of this It's script block.
        $braceDepth = 0
        $started = $false
        $itEnd = $content.Length
        for ($i = $itStart; $i -lt $content.Length; $i++) {
            $ch = $content[$i]
            if ($ch -eq '{') { $braceDepth++; $started = $true }
            elseif ($ch -eq '}') {
                $braceDepth--
                if ($started -and $braceDepth -eq 0) { $itEnd = $i + 1; break }
            }
        }
        $itText = $content.Substring($itStart, [Math]::Min($itEnd - $itStart, $content.Length - $itStart))

        # Fall back: if no testId in the It name, look for it in the It's tag list (-Tag "MT.1234")
        if (-not $id) {
            $tagMatch = [regex]::Match($itText, "${idPattern}", 'IgnoreCase')
            if ($tagMatch.Success) { $id = $tagMatch.Groups[1].Value }
        }
        if (-not $id) { continue }

        # Find the enclosing Describe/Context tag arguments (everything before $itStart in this file).
        $headerText = $content.Substring(0, $itStart)
        # Limit to the most recent Describe/Context block by collecting their tag lists.
        # We don't need precise scoping — license tags only appear on Describe/Context anyway.
        $enclosingText = $headerText

        # Find function name(s) invoked inside the It.
        # Special case: Test-MtEidscaControl -CheckId X -> Test-MtEidscaX
        $functionNames = [System.Collections.Generic.List[string]]::new()
        foreach ($fnMatch in [regex]::Matches($itText, '\b(Test-[A-Za-z0-9_]+)\b')) {
            $fn = $fnMatch.Groups[1].Value
            if ($fn -eq 'Test-MtEidscaControl') {
                $checkIdMatch = [regex]::Match($itText, '-CheckId\s+([A-Z0-9]+)')
                if ($checkIdMatch.Success) {
                    $functionNames.Add('Test-MtEidsca' + $checkIdMatch.Groups[1].Value)
                }
            } elseif ($fn -ne 'Test-Path' -and $fn -ne 'Test-MtConnection') {
                $functionNames.Add($fn)
            }
        }
        $functionName = if ($functionNames.Count -gt 0) { $functionNames[0] } else { $null }

        # Multiple It blocks with the same Id can exist (CAWhatIf foreach loop). Append.
        if ($testIndex.ContainsKey($id)) {
            $testIndex[$id].ItText += "`n$itText"
            if (-not $testIndex[$id].EnclosingText.Contains($enclosingText)) {
                $testIndex[$id].EnclosingText += "`n$enclosingText"
            }
            if (-not $testIndex[$id].FunctionName -and $functionName) {
                $testIndex[$id].FunctionName = $functionName
            }
        } else {
            $testIndex[$id] = @{
                ItText        = $itText
                EnclosingText = $enclosingText
                FunctionName  = $functionName
                File          = $file.FullName
            }
        }
    }
}

Write-Host "Parsed $($testIndex.Count) unique test IDs from .Tests.ps1 files." -ForegroundColor Cyan

# --- Pass 2: for each TestSettings entry, derive license tokens ---

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

$licenseMap = [ordered]@{}
$tally = @{}
$tbdIds = [System.Collections.Generic.List[string]]::new()

foreach ($setting in $config.TestSettings) {
    $id = $setting.Id
    $tokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    # Resolve to testIndex with parent-prefix fallback (config has MT.1033.0 but
    # the test only encodes MT.1033 because the .0 is interpolated at runtime).
    $entry = $null
    if ($testIndex.ContainsKey($id)) {
        $entry = $testIndex[$id]
    } else {
        $parent = $id
        while ($parent -match '\.\d+$' -and -not $entry) {
            $parent = $parent -replace '\.\d+$', ''
            if ($testIndex.ContainsKey($parent)) { $entry = $testIndex[$parent] }
        }
    }

    $functionFile = $null

    if ($entry) {
        # Signals 1-3 from the It block.
        foreach ($t in (Get-LicenseTokensFromText -Text $entry.ItText)) { [void] $tokens.Add($t) }

        # Signal 5 from the enclosing Describe/Context header.
        foreach ($t in (Get-LicenseTokensFromText -Text $entry.EnclosingText)) { [void] $tokens.Add($t) }

        # Signal 4: scan the underlying PowerShell function file.
        if ($entry.FunctionName) {
            $functionFile = Get-FunctionFileForTest -TestFunctionName $entry.FunctionName
            if ($functionFile) {
                $functionContent = Get-Content -Path $functionFile -Raw
                foreach ($t in (Get-LicenseTokensFromText -Text $functionContent)) { [void] $tokens.Add($t) }
            }
        }
    }

    # Signal 7: explicit license-requirement statements in the website doc and
    # in the function's companion .md (e.g. "Microsoft Entra ID P1 or P2 is required").
    # Catches license requirements that the test code doesn't gate on.
    $markdownFile = Get-MarkdownFileForId -Id $id
    if ($markdownFile) {
        $mdContent = Get-Content -Path $markdownFile -Raw
        foreach ($t in (Get-MarkdownSignalsFromText -Text $mdContent)) { [void] $tokens.Add($t) }
    }
    if ($functionFile) {
        $companionMd = [System.IO.Path]::ChangeExtension($functionFile, '.md')
        if (Test-Path $companionMd) {
            $companionContent = Get-Content -Path $companionMd -Raw
            foreach ($t in (Get-MarkdownSignalsFromText -Text $companionContent)) { [void] $tokens.Add($t) }
        }
    }

    if ($tokens.Count -eq 0) {
        # Signal 6: suite default
        if ($id -like 'AZDO.*')      { [void] $tokens.Add('AzureDevOps') }
        elseif (-not $entry)         { [void] $tokens.Add('TBD') }
        # else: analyzed but no premium signal -> [] (baseline is adequate)
    }

    $licenses = @($tokens | Sort-Object)
    $licenseMap[$id] = $licenses

    if ($licenses.Count -eq 0) {
        $tally['(baseline [])'] = ($tally['(baseline [])'] ?? 0) + 1
    } else {
        foreach ($t in $licenses) {
            $tally[$t] = ($tally[$t] ?? 0) + 1
        }
    }

    if ($licenses -contains 'TBD') { $tbdIds.Add($id) }
}

Write-Host ""
Write-Host "License token tally:" -ForegroundColor Cyan
$tally.GetEnumerator() | Sort-Object Name | ForEach-Object {
    "  {0,-22} {1,4}" -f $_.Key, $_.Value
}
Write-Host ""
Write-Host "$($tbdIds.Count) entries marked TBD:" -ForegroundColor Yellow
$tbdIds | ForEach-Object { "  $_" } | Write-Host

if ($DryRun) {
    Write-Host ""
    Write-Host "Spot checks:" -ForegroundColor Cyan
    foreach ($probeId in @('MT.1029', 'MT.1034.0', 'MT.1033.0', 'CISA.MS.AAD.4.1', 'CISA.MS.AAD.7.7', 'CISA.MS.EXO.15.1', 'CIS.M365.1.3.6', 'AZDO.1000', 'EIDSCA.AP04', 'EIDSCA.AF01')) {
        $tokens = $licenseMap[$probeId]
        $rendered = if ($tokens.Count -eq 0) { '[]' } else { '[' + ($tokens -join ', ') + ']' }
        "  {0,-22} {1}" -f $probeId, $rendered
    }
    Write-Host ""
    Write-Host "Dry run — config not modified." -ForegroundColor Green
    return
}

# --- Pass 3: write the Licenses field into maester-config.json (text-level edit) ---

$json = Get-Content -Path $configPath -Raw
$lines = $json -split "`r?`n"
$out = [System.Collections.Generic.List[string]]::new()

# State machine: when we see `"Id": "..."` we record the Id; when we close that
# object's body (the line that is exactly "    }" or "    },") we have already
# emitted "Title" earlier — so we insert the Licenses line just before the close.
$pendingId = $null
$pendingObjectLines = [System.Collections.Generic.List[string]]::new()
$pendingIndent = ''
$inTestSettingsObject = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if (-not $inTestSettingsObject) {
        # Detect entering an item: a line that opens a top-level TestSettings object.
        # Pattern: indented "{" inside the TestSettings array.
        if ($line -match '^(\s*)\{\s*$') {
            $indent = $matches[1]
            # Peek ahead a few lines for "Id":
            $peekId = $null
            for ($j = $i + 1; $j -lt [Math]::Min($i + 10, $lines.Count); $j++) {
                if ($lines[$j] -match '"Id":\s*"([^"]+)"') { $peekId = $matches[1]; break }
                if ($lines[$j] -match '^\s*\}') { break }
            }
            if ($peekId -and $licenseMap.Contains($peekId)) {
                $inTestSettingsObject = $true
                $pendingId = $peekId
                $pendingIndent = $indent
                $pendingObjectLines.Clear()
                $pendingObjectLines.Add($line)
                continue
            }
        }
        $out.Add($line)
        continue
    }

    # Inside a tracked TestSettings object.
    $pendingObjectLines.Add($line)

    # Detect close of this object: a line that is exactly indent + "}" or "}," or starts with that.
    if ($line -match "^$([regex]::Escape($pendingIndent))\}\,?\s*$") {
        # Insert the Licenses line just before the closing brace.
        $closingLine = $pendingObjectLines[$pendingObjectLines.Count - 1]
        $bodyLines = [System.Collections.Generic.List[string]]::new()
        for ($k = 0; $k -lt $pendingObjectLines.Count - 1; $k++) {
            $bodyLines.Add($pendingObjectLines[$k])
        }

        # Idempotency: if a Licenses field already exists in this object, drop it
        # so we can rewrite cleanly. Anything else (Id/Severity/Title/etc) is left alone.
        for ($k = $bodyLines.Count - 1; $k -ge 0; $k--) {
            if ($bodyLines[$k] -match '^\s*"Licenses"\s*:') { $bodyLines.RemoveAt($k) }
        }

        # The previous body line may or may not have a trailing comma (depends on
        # whether the object originally ended with Licenses or with another field).
        # Normalize: ensure the last remaining body line has a trailing comma so we
        # can append the new Licenses line.
        $lastBodyIdx = $bodyLines.Count - 1
        $lastBody = $bodyLines[$lastBodyIdx]
        if ($lastBody -notmatch ',\s*$') {
            $bodyLines[$lastBodyIdx] = $lastBody.TrimEnd() + ','
        }

        $licenses = $licenseMap[$pendingId]
        $licenseJson = if ($licenses.Count -eq 0) {
            '[]'
        } else {
            '[' + (($licenses | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']'
        }
        # Detect inner indentation by sampling an existing body line (first non-brace line).
        $innerIndent = $pendingIndent + '  '
        for ($k = 1; $k -lt $bodyLines.Count; $k++) {
            if ($bodyLines[$k] -match '^(\s+)"') { $innerIndent = $matches[1]; break }
        }

        foreach ($bl in $bodyLines) { $out.Add($bl) }
        $out.Add("$innerIndent`"Licenses`": $licenseJson")
        $out.Add($closingLine)

        $inTestSettingsObject = $false
        $pendingId = $null
        $pendingObjectLines.Clear()
    }
}

# Detect original line ending; default to LF (the repo's convention here).
$lineEnding = if ($json -match "`r`n") { "`r`n" } else { "`n" }
$newJson = $out -join $lineEnding
if ($json.EndsWith("`n") -and -not $newJson.EndsWith("`n")) { $newJson += $lineEnding }

# Sanity check: still valid JSON.
try {
    $null = $newJson | ConvertFrom-Json
} catch {
    throw "Generated JSON is invalid: $_"
}

# Use [IO.File]::WriteAllText to avoid PowerShell's CRLF tendencies.
[System.IO.File]::WriteAllText($configPath, $newJson, [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "Wrote $configPath." -ForegroundColor Green

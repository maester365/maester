<#
.SYNOPSIS
    Verifies the Licenses array on every TestSettings entry in tests/maester-config.json
    against signals independently re-derived from the Pester test, the underlying PowerShell
    function, and the markdown doc.

.DESCRIPTION
    For each TestSettings entry, prints:
        Id  | Config | Test | Function | Markdown | Verdict

    Verdicts:
        OK             — config matches the union of code-derived signals
        OK_MD          — config tokens are not in code, but markdown evidence supports them
        BASELINE       — config is [] and no signals anywhere (intentional baseline)
        ORPHAN         — no test file backs this Id (config-only entry)
        TBD            — config says TBD; no signals found
        MISMATCH       — code signals contradict the config (config is missing or has tokens
                         that aren't backed by code or markdown)

    Pass -OnlyMismatches to show only rows that warrant review: MISMATCH, TBD, and ORPHAN.
    OK / OK_MD / BASELINE rows are filtered out.

.EXAMPLE
    pwsh build/Test-MaesterConfigLicenses.ps1
    pwsh build/Test-MaesterConfigLicenses.ps1 -OnlyMismatches
#>
[CmdletBinding()]
param(
    [switch] $OnlyMismatches
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$testsRoot = Join-Path $repoRoot 'tests'
$psPublicRoot = Join-Path $repoRoot 'powershell/public'
$psInternalRoot = Join-Path $repoRoot 'powershell/internal'
$docsRoot = Join-Path $repoRoot 'website/docs/tests'
$configPath = Join-Path $testsRoot 'maester-config.json'

<#
    To Do: Update mapping and actually used tokens to match Microsoft's official license names and SKUs,
    rather than the internal shorthand we used during development. The mapping is only used for signal
    extraction and display; the config can use any token names we want (e.g. "EntraIDP1" or "AzureADPremiumP1"
    or "AADPremiumP1" could all be fine as long as we're consistent in the config and the mapping). Using
    official names would just make the output clearer to external audiences and reduce the mental mapping.
#>

# Canonical token vocabulary. Mirrors $canonicalTokens in Update-MaesterConfigLicenses.ps1
# so the License:<Token> extractor below rejects tokens neither script recognizes.
$canonicalTokens = @(
    'EntraIDP1', 'EntraIDP2', 'EntraIDGovernance',
    'EntraWorkloadIDP1', 'EntraWorkloadIDP2',
    'Eop', 'MdoP1', 'MdoP2',
    'ExoDlp', 'AdvAudit', 'DefenderXDR',
    'Intune', 'CustomerLockbox',
    'AzureDevOps', 'TBD'
)

# Token vocabulary mirrors Get-MtLicenseInformation.ps1 + Get-MtSkippedReason.ps1.
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

# Markdown free-text phrase -> token. Keys are case-insensitive substrings; the verifier
# uses these to detect license claims authors made in remediation/overview prose.
$markdownPhraseMap = [ordered]@{
    'entra id p2 license'                    = 'EntraIDP2'
    'entra id p1 license'                    = 'EntraIDP1'
    'entra id p2'                            = 'EntraIDP2'
    'entra id p1'                            = 'EntraIDP1'
    'entra id governance'                    = 'EntraIDGovernance'
    'aad premium p2'                         = 'EntraIDP2'
    'aad premium p1'                         = 'EntraIDP1'
    'azure ad premium p2'                    = 'EntraIDP2'
    'azure ad premium p1'                    = 'EntraIDP1'
    'workload identities premium'            = 'EntraWorkloadIDP1'
    'defender for office 365 plan 2'         = 'MdoP2'
    'defender for office 365 plan 1'         = 'MdoP1'
    'defender for office (plan 2)'           = 'MdoP2'
    'defender for office (plan 1)'           = 'MdoP1'
    'defender for office 365 (plan 2)'       = 'MdoP2'
    'defender for office 365 (plan 1)'       = 'MdoP1'
    'microsoft defender xdr'                 = 'DefenderXDR'
    'defender xdr'                           = 'DefenderXDR'
    'microsoft intune'                       = 'Intune'
    'customer lockbox'                       = 'CustomerLockbox'
    'm365 advanced auditing'                 = 'AdvAudit'
    'microsoft 365 advanced auditing'        = 'AdvAudit'
    'purview audit (premium)'                = 'AdvAudit'
    'exchange online dlp'                    = 'ExoDlp'
    'microsoft purview data loss prevention' = 'ExoDlp'
    'exchange online protection'             = 'Eop'
}

$idPattern = '(MT\.\d+|CIS\.[A-Za-z0-9.]+|CISA\.[A-Za-z0-9.]+|EIDSCA\.[A-Z0-9]+|ORCA\.\d+(?:\.\d+)?|AZDO\.\d+)'

function Get-CodeSignals {
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $tokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    foreach ($m in [regex]::Matches($Text, '-SkippedBecause\s+(NotLicensed[A-Za-z0-9]+)')) {
        $reason = $m.Groups[1].Value
        if ($skipReasonMap.ContainsKey($reason)) { [void] $tokens.Add($skipReasonMap[$reason]) }
    }
    foreach ($m in [regex]::Matches($Text, "Get-MtLicenseInformation\s+(?:-Product\s+)?['""]?([A-Za-z]+)['""]?\s*\)?\s*(-eq|-ne)\s*['""]([A-Za-z0-9]+)['""]")) {
        $product = $m.Groups[1].Value; $op = $m.Groups[2].Value; $val = $m.Groups[3].Value
        switch ("$product/$op/$val") {
            'EntraID/-ne/P2' { [void] $tokens.Add('EntraIDP2'); break }
            'EntraID/-eq/P2' { [void] $tokens.Add('EntraIDP2'); break }
            'EntraID/-ne/P1' { [void] $tokens.Add('EntraIDP1'); break }
            'EntraID/-eq/Free' { [void] $tokens.Add('EntraIDP1'); break }
            'EntraID/-eq/Governance' { [void] $tokens.Add('EntraIDGovernance'); break }
            default { }
        }
    }
    foreach ($m in [regex]::Matches($Text, "\$EntraIDPlan\s*-eq\s*['""]Free['""]")) { [void] $tokens.Add('EntraIDP1') }
    foreach ($m in [regex]::Matches($Text, "\$EntraIDPlan\s*-ne\s*['""]P2['""]")) { [void] $tokens.Add('EntraIDP2') }
    foreach ($m in [regex]::Matches($Text, "\$DefenderPlan\s*-ne\s*['""]DefenderXDR['""]")) { [void] $tokens.Add('DefenderXDR') }
    foreach ($pair in $tagMap.GetEnumerator()) {
        if ($Text -match "[""']\s*$([regex]::Escape($pair.Key))\s*[""']") { [void] $tokens.Add($pair.Value) }
    }
    foreach ($m in [regex]::Matches($Text, "[""']License:([A-Za-z0-9]+)[""']")) {
        $candidate = $m.Groups[1].Value
        if ($canonicalTokens -contains $candidate) { [void] $tokens.Add($candidate) }
    }
    return @($tokens | Sort-Object)
}

function Get-MarkdownSignals {
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $tokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    # Markdown docs are auto-generated from Pester Describe tags. The Category line and
    # Tags row both come from the same source — to make markdown signal *independent*
    # we exclude the front-matter keywords block and the Test Metadata table, then scan
    # the prose for license phrases.
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
    param([Parameter(Mandatory)] [string] $TestFunctionName)
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
    # Try direct, then parent prefix (MT.1033.0 -> MT.1033.md is unlikely but try).
    $candidate = Get-ChildItem -Path $docsRoot -Recurse -Filter "$Id.md" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
    $parent = $Id
    while ($parent -match '\.\d+$') {
        $parent = $parent -replace '\.\d+$', ''
        $candidate = Get-ChildItem -Path $docsRoot -Recurse -Filter "$parent.md" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    return $null
}

# --- Pass 1: index .Tests.ps1 by testId, capturing per-It text + enclosing header + function refs ---

$testIndex = @{}

foreach ($file in Get-ChildItem -Path $testsRoot -Recurse -Filter '*.Tests.ps1' -File) {
    $content = Get-Content -Path $file.FullName -Raw
    if (-not $content) { continue }
    $itMatches = [regex]::Matches($content, '(?ms)\bIt\s+["''](?<name>[^"'']+)["'']')
    foreach ($itMatch in $itMatches) {
        $itStart = $itMatch.Index
        $name = $itMatch.Groups['name'].Value
        $idMatch = [regex]::Match($name, "^${idPattern}:")
        $id = $null
        if ($idMatch.Success) { $id = $idMatch.Groups[1].Value }

        $braceDepth = 0; $started = $false; $itEnd = $content.Length
        for ($i = $itStart; $i -lt $content.Length; $i++) {
            $ch = $content[$i]
            if ($ch -eq '{') { $braceDepth++; $started = $true }
            elseif ($ch -eq '}') { $braceDepth--; if ($started -and $braceDepth -eq 0) { $itEnd = $i + 1; break } }
        }
        $itText = $content.Substring($itStart, [Math]::Min($itEnd - $itStart, $content.Length - $itStart))
        if (-not $id) {
            $tagMatch = [regex]::Match($itText, $idPattern, 'IgnoreCase')
            if ($tagMatch.Success) { $id = $tagMatch.Groups[1].Value }
        }
        if (-not $id) { continue }

        $headerText = $content.Substring(0, $itStart)

        $functionNames = [System.Collections.Generic.List[string]]::new()
        foreach ($fnMatch in [regex]::Matches($itText, '\b(Test-[A-Za-z0-9_]+)\b')) {
            $fn = $fnMatch.Groups[1].Value
            if ($fn -eq 'Test-MtEidscaControl') {
                $checkIdMatch = [regex]::Match($itText, '-CheckId\s+([A-Z0-9]+)')
                if ($checkIdMatch.Success) { $functionNames.Add('Test-MtEidsca' + $checkIdMatch.Groups[1].Value) }
            } elseif ($fn -ne 'Test-Path' -and $fn -ne 'Test-MtConnection') {
                $functionNames.Add($fn)
            }
        }
        $functionName = if ($functionNames.Count -gt 0) { $functionNames[0] } else { $null }

        if ($testIndex.ContainsKey($id)) {
            $testIndex[$id].ItText += "`n$itText"
            if (-not $testIndex[$id].EnclosingText.Contains($headerText)) {
                $testIndex[$id].EnclosingText += "`n$headerText"
            }
            if (-not $testIndex[$id].FunctionName -and $functionName) { $testIndex[$id].FunctionName = $functionName }
        } else {
            $testIndex[$id] = @{
                ItText = $itText; EnclosingText = $headerText; FunctionName = $functionName; File = $file.FullName
            }
        }
    }
}

# --- Pass 2: per-id verification ---

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

$rows = [System.Collections.Generic.List[object]]::new()
$counts = @{ OK = 0; OK_MD = 0; BASELINE = 0; ORPHAN = 0; TBD = 0; MISMATCH = 0 }

foreach ($setting in $config.TestSettings) {
    $id = $setting.Id
    $configTokens = @($setting.Licenses | Where-Object { $_ })
    $configIsTBD = ($setting.Licenses -contains 'TBD')

    # Resolve test entry, with parent-prefix fallback.
    $entry = $null
    if ($testIndex.ContainsKey($id)) { $entry = $testIndex[$id] }
    else {
        $parent = $id
        while ($parent -match '\.\d+$' -and -not $entry) {
            $parent = $parent -replace '\.\d+$', ''
            if ($testIndex.ContainsKey($parent)) { $entry = $testIndex[$parent] }
        }
    }

    $testTokens = @()
    $functionTokens = @()
    $markdownTokens = @()

    if ($entry) {
        $itAndHeader = $entry.ItText + "`n" + $entry.EnclosingText
        $testTokens = Get-CodeSignals -Text $itAndHeader

        if ($entry.FunctionName) {
            $functionFile = Get-FunctionFileForTest -TestFunctionName $entry.FunctionName
            if ($functionFile) {
                $functionContent = Get-Content -Path $functionFile -Raw
                $functionTokens = Get-CodeSignals -Text $functionContent
            }
        }
    }

    $markdownFile = Get-MarkdownFileForId -Id $id
    if ($markdownFile) {
        $markdownContent = Get-Content -Path $markdownFile -Raw
        $markdownTokens = Get-MarkdownSignals -Text $markdownContent
    }

    # Also scan the companion .md beside the PowerShell function (e.g.
    # powershell/public/maester/entra/Test-MtCaAzureDevOps.md), which often
    # contains a "Licensing requirement: Microsoft Entra ID P1 or P2..." line
    # that does NOT appear in the website doc.
    if ($entry -and $entry.FunctionName) {
        $functionFile = Get-FunctionFileForTest -TestFunctionName $entry.FunctionName
        if ($functionFile) {
            $companionMd = [System.IO.Path]::ChangeExtension($functionFile, '.md')
            if (Test-Path $companionMd) {
                $companionContent = Get-Content -Path $companionMd -Raw
                $companionTokens = Get-MarkdownSignals -Text $companionContent
                $existing = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($t in $markdownTokens) { if ($t) { [void] $existing.Add($t) } }
                foreach ($t in $companionTokens) { if ($t) { [void] $existing.Add($t) } }
                $markdownTokens = @($existing | Sort-Object)
            }
        }
    }

    # Suite default for AZDO is correct without any signal.
    $expectAzureDevOps = ($id -like 'AZDO.*' -and $testTokens.Count -eq 0 -and $functionTokens.Count -eq 0 -and $markdownTokens.Count -eq 0)

    $expectedUnion = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $testTokens) { [void] $expectedUnion.Add($t) }
    foreach ($t in $functionTokens) { [void] $expectedUnion.Add($t) }
    # Markdown is a *cross-check* only — phrases like "Defender for Office 365 Plan 2"
    # routinely appear in remediation prose for tests that gate at Plan 1, so we don't
    # add markdown tokens to the expected set unless they reinforce code signals.
    # We'll still surface them in the row for review.

    if ($expectAzureDevOps) { [void] $expectedUnion.Add('AzureDevOps') }

    $verdict = $null
    if (-not $entry -and ($id -notlike 'AZDO.*')) {
        $verdict = 'ORPHAN'
    } elseif ($configIsTBD) {
        $verdict = 'TBD'
    } elseif ($expectedUnion.Count -eq 0 -and $configTokens.Count -eq 0) {
        $verdict = 'BASELINE'
    } else {
        $configSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($t in $configTokens) { if ($t) { [void] $configSet.Add($t) } }
        $markdownSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($t in $markdownTokens) { if ($t) { [void] $markdownSet.Add($t) } }

        # Required: every code-derived token MUST be in the config.
        $missingFromConfig = $expectedUnion | Where-Object { -not $configSet.Contains($_) }

        # Extras in config that aren't backed by code — OK only if markdown supports them.
        $markdownOnly = @($configSet | Where-Object { -not $expectedUnion.Contains($_) -and $markdownSet.Contains($_) })
        $unsupported = @($configSet | Where-Object { -not $expectedUnion.Contains($_) -and -not $markdownSet.Contains($_) })

        if ($missingFromConfig -or $unsupported) {
            $verdict = 'MISMATCH'
        } elseif ($markdownOnly.Count -gt 0) {
            $verdict = 'OK_MD'   # config matches code + markdown-justified extras
        } else {
            $verdict = 'OK'
        }
    }

    $counts[$verdict] += 1

    $rows.Add([pscustomobject]@{
            Id       = $id
            Config   = ($configTokens -join ', ')
            Test     = ($testTokens -join ', ')
            Function = ($functionTokens -join ', ')
            Markdown = ($markdownTokens -join ', ')
            Verdict  = $verdict
        })
}

# --- Output ---

$display = if ($OnlyMismatches) { $rows | Where-Object { $_.Verdict -in @('MISMATCH', 'TBD', 'ORPHAN') } } else { $rows }

$display | Format-Table -AutoSize | Out-String -Width 240 | Write-Host

Write-Host ''
Write-Host 'Verdict counts:' -ForegroundColor Cyan
$counts.GetEnumerator() | Sort-Object Name | ForEach-Object { '  {0,-10} {1,4}' -f $_.Key, $_.Value } | Write-Host

# Also surface markdown-only signals (phrases in docs that were not in code).
Write-Host ''
Write-Host 'Markdown-only signals (in markdown but not in code) — review for missed licenses:' -ForegroundColor Yellow
$mdOnly = $rows | Where-Object {
    $cfg = ($_.Config -split ',\s*') | Where-Object { $_ }
    $code = (($_.Test -split ',\s*') + ($_.Function -split ',\s*')) | Where-Object { $_ }
    $md = ($_.Markdown -split ',\s*') | Where-Object { $_ }
    foreach ($t in $md) { if ($t -and ($t -notin $code) -and ($t -notin $cfg)) { return $true } }
    $false
}
if ($mdOnly) {
    $mdOnly | Format-Table Id, Config, Markdown -AutoSize | Out-String -Width 200 | Write-Host
} else {
    Write-Host '  (none)' -ForegroundColor DarkGray
}

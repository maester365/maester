#Requires -Version 7.0
<#
.SYNOPSIS
    Generates one Markdown page per MT.Zta.* test under
    `website/docs/tests/maester/MT.Zta.NNNN.md`, derived from the actual test
    files' It titles + Description heredocs.

.DESCRIPTION
    Maester convention is one Markdown page per test id (mirrors what
    `https://maester.dev/docs/tests/MT.NNNN` resolves to). This script walks
    `tests/Zta/*.Tests.ps1`, parses each `It 'MT.Zta.NNNN: <title>...'` block,
    extracts the Description heredoc that the test body passes to
    `Add-MtTestResultDetail -Description ...`, and writes a Docusaurus-
    compatible page with the same shape Maester core uses for MT.NNNN pages.

    Run this whenever a description is edited or a new test is added — the
    pages are deterministic from the source, no hand-editing needed.

.PARAMETER ForkRoot
    Root of the Maester fork repo. Defaults to two levels up from this script.

.EXAMPLE
    ./build/Update-MtZtaTestDocs.ps1

    Regenerates all per-test pages.

.LINK
    https://maester.dev/docs/zero-trust-assessment
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $ForkRoot = (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testsDir = Join-Path $ForkRoot 'tests/Zta'
$docsDir  = Join-Path $ForkRoot 'website/docs/tests/maester'
if (-not (Test-Path $testsDir)) { throw "tests/Zta not found at $testsDir" }
if (-not (Test-Path $docsDir))  { New-Item -Path $docsDir -ItemType Directory -Force | Out-Null }

# Parse one .Tests.ps1 file, return an array of @{ Id; Title; Severity; Description }.
function Get-MtZtaTestsFromFile {
    param([string] $Path)

    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    if ($errs.Count -gt 0) {
        throw ("Parse errors in {0}: {1}" -f $Path, $errs[0].Message)
    }

    # Find all top-level `It` invocations, regardless of nesting depth.
    $itCalls = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.CommandAst] -and
        $n.CommandElements.Count -gt 1 -and
        $n.CommandElements[0].Extent.Text -eq 'It'
    }, $true)

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($it in $itCalls) {
        # First positional argument after `It` is the title string.
        $titleArg = $it.CommandElements[1]
        $title = $titleArg.Extent.Text.Trim("'`"")
        if ($title -notmatch '^(MT\.Zta\.\d+):\s*(.+?)(?:\.\s*See\s+https://.*)?$') { continue }
        $id    = $Matches[1]
        $short = $Matches[2].TrimEnd('.')

        # -Tag parameter — look for `Severity:Level`
        $severity = 'Medium'
        $tagsAst = $it.CommandElements | Where-Object {
            $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Tag'
        }
        if ($tagsAst) {
            $tagIdx = $it.CommandElements.IndexOf($tagsAst[0])
            if ($tagIdx -ge 0 -and $it.CommandElements.Count -gt $tagIdx + 1) {
                $tagArg = $it.CommandElements[$tagIdx + 1].Extent.Text
                if ($tagArg -match "Severity:(\w+)") { $severity = $Matches[1] }
            }
        }

        # Description heredoc — locate the ScriptBlockExpression argument of the It
        # call (the actual It body), then find heredocs inside it.
        $itBody = $null
        $sbArg = $it.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -First 1
        if ($sbArg) { $itBody = $sbArg.ScriptBlock }

        $description = ''
        if ($itBody) {
            $heredocs = $itBody.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $n.StringConstantType -in @('SingleQuotedHereString','DoubleQuotedHereString')
            }, $true)
            # Heuristic: the first heredoc whose value starts with "## What this test checks" is the description.
            foreach ($hd in $heredocs) {
                if ($hd.Value -match '(?ms)^## What this test checks') {
                    $description = $hd.Value
                    break
                }
            }
        }

        $results.Add([pscustomobject]@{
            Id          = $id
            Title       = $short
            Severity    = $severity
            Description = $description
            SourceFile  = (Split-Path -Leaf $Path)
        }) | Out-Null
    }
    return ,$results.ToArray()
}

$allTests = New-Object System.Collections.Generic.List[object]
foreach ($file in Get-ChildItem $testsDir -Filter 'Test-MtZta.*.Tests.ps1' -File) {
    foreach ($t in (Get-MtZtaTestsFromFile -Path $file.FullName)) {
        $allTests.Add($t) | Out-Null
    }
}

Write-Host ("Discovered {0} MT.Zta.* tests across {1} files." -f $allTests.Count, (Get-ChildItem $testsDir -Filter '*.Tests.ps1').Count)

# De-duplicate (data-driven tests may appear multiple times; first occurrence wins).
$seen = @{}
$written = 0
foreach ($t in $allTests) {
    if ($seen.ContainsKey($t.Id)) { continue }
    $seen[$t.Id] = $true

    # Split the description into 'Description' + 'How to fix' + 'Related tests' sections.
    # The test heredocs use `## What this test checks` and `## How to remediate` and
    # `## Related Maester core tests` headings — preserve those, but rewrite as
    # Docusaurus-flavored sections matching the MT.NNNN.md format.
    $descIntro = $t.Description -replace '(?ms)^## What this test checks\s*\r?\n', ''
    # Split on `## ` headings
    $sections = [regex]::Split($descIntro, "(?m)^## ")
    $whatBody    = $sections[0].Trim()
    $remediate   = ''
    $related     = ''
    foreach ($s in $sections | Select-Object -Skip 1) {
        if ($s -match '^How to remediate') {
            $remediate = ($s -replace '^How to remediate\s*\r?\n', '').Trim()
        } elseif ($s -match '^Related Maester core tests') {
            $related = ($s -replace '^Related Maester core tests.*?\r?\n', '').Trim()
        } elseif ($s -match '^How to declare break-glass accounts') {
            $remediate = ($s -replace '^How to declare break-glass accounts\s*\r?\n', '## Declaring break-glass accounts`n`n').Trim() + "`n`n" + $remediate
        } elseif ($s -match '^Why a privileged user') {
            # Sub-discussion under "What this test checks" — append to that body
            $whatBody += "`n`n## " + $s.Trim()
        }
    }

    # Frontmatter description: short version of the test title with the description's first paragraph.
    $firstPara = ($whatBody -split "(?ms)\r?\n\s*\r?\n" | Select-Object -First 1).Trim()
    $shortDesc = ($firstPara -replace '\s+', ' ').Trim()
    if ($shortDesc.Length -gt 280) { $shortDesc = $shortDesc.Substring(0, 277) + '...' }
    # YAML frontmatter requires escaping double-quotes and backticks inside the quoted string.
    $shortDescYaml = $shortDesc -replace '"', '\"' -replace '`', "'"

    $page = @"
---
title: $($t.Id) - $($t.Title)
description: "$shortDescYaml"
slug: /tests/$($t.Id)
sidebar_class_name: hidden
---

# $($t.Title)

| Severity | Source |
| --- | --- |
| $($t.Severity) | [``$($t.SourceFile)``](https://github.com/maester365/maester/blob/main/tests/Zta/$($t.SourceFile)) |

## Description

$whatBody

"@

    if ($remediate) {
        $page += @"
## How to fix

$remediate

"@
    }

    if ($related) {
        $page += @"
## Related Maester core tests

$related

"@
    }

    $page += @"
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
"@

    $outPath = Join-Path $docsDir "$($t.Id).md"
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($outPath, $page, $utf8Bom)
    $written++
}

Write-Host ("Wrote {0} per-test pages under {1}" -f $written, $docsDir)

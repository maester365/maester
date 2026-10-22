<#
.SYNOPSIS
    Generates the Claude Code agent and skill files and the docs page from the Copilot files.

.DESCRIPTION
    The agents and skills that ship in this repository have one source of truth each:

    - an agent is .github/agents/<name>.agent.md
    - a skill is .github/skills/<name>/SKILL.md

    GitHub Copilot reads those files directly. This script generates everything else from them:

    - .claude/agents/<name>.md, with the same body and Claude Code's frontmatter (the tool list comes
      from the agent's metadata.claude-tools; "all" leaves the tools line out)
    - .claude/skills/<name>/SKILL.md, a pointer to the canonical skill
    - website/docs/agents-and-skills.md, the list of agents and skills on maester.dev

    Relative links in an agent's body are rewritten so they still resolve from .claude/agents/.

    Each source file must have name and description in its frontmatter, and metadata.audience and
    metadata.summary (who uses it, and one sentence on what it does). Run this script after editing
    any of them. With -Check it changes nothing and fails when a generated file is out of date;
    powershell/tests/general/AgentFiles.Tests.ps1 runs that check in CI.

.PARAMETER Check
    Compare the generated files with the ones on disk and throw if any differ, without writing.

.EXAMPLE
    ./build/github/Update-AgentFiles.ps1

    Regenerates the Claude Code files and the docs page.

.EXAMPLE
    ./build/github/Update-AgentFiles.ps1 -Check

    Lists the generated files that are out of date and throws if there are any.
#>
[CmdletBinding()]
param(
    [switch] $Check
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$repoUrl = 'https://github.com/maester365/maester/blob/main'
$generator = 'build/github/Update-AgentFiles.ps1'

function Read-Frontmatter {
    # Reads the small YAML subset these files use: scalars, folded scalars (>-), lists and one-level maps.
    param([Parameter(Mandatory)] [string] $Path)
    $text = (Get-Content -Path $Path -Raw -Encoding utf8) -replace "`r`n", "`n"
    if ($text -notmatch '(?s)^﻿?---\n(.*?)\n---\n(.*)$') { throw "$Path has no YAML frontmatter." }
    $lines = $Matches[1] -split "`n"
    $body = $Matches[2].TrimStart("`n")
    $data = [ordered]@{}
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -notmatch '^([A-Za-z0-9_-]+):\s*(.*)$') { $i++; continue }
        $key = $Matches[1]; $value = $Matches[2]
        $i++
        if ($value -in '>-', '>', '|', '|-') {
            $parts = @()
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s+(.*)$') { $parts += $Matches[1].Trim(); $i++ }
            $data[$key] = $parts -join ' '
        } elseif ($value -eq '') {
            $items = @(); $map = [ordered]@{}
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s+') {
                if ($lines[$i] -match '^\s+-\s+(.*)$') { $items += $Matches[1].Trim() }
                elseif ($lines[$i] -match '^\s+([A-Za-z0-9_-]+):\s*(.*)$') { $map[$Matches[1]] = $Matches[2].Trim().Trim('"') }
                $i++
            }
            $data[$key] = if ($map.Count -gt 0) { $map } else { $items }
        } else {
            $data[$key] = $value.Trim().Trim('"')
        }
    }
    [pscustomobject]@{ Data = $data; Body = $body }
}

function Format-Folded {
    # Folds a description into a YAML ">-" block wrapped at about 88 columns.
    param([string] $Text)
    $out = [System.Collections.Generic.List[string]]::new(); $line = ''
    foreach ($word in ($Text -split '\s+')) {
        if ($line -and ($line.Length + 1 + $word.Length) -gt 86) { $out.Add("  $line"); $line = $word }
        else { $line = if ($line) { "$line $word" } else { $word } }
    }
    if ($line) { $out.Add("  $line") }
    ">-`n" + ($out -join "`n")
}

function Convert-RelativeLinks {
    # Rewrites relative Markdown link targets written for one folder so they resolve from another.
    param([string] $Markdown, [string] $FromDir, [string] $ToDir)
    [regex]::Replace($Markdown, '\]\((?!https?:|mailto:|#|/)([^)\s]+)\)', {
            param($m)
            $target = $m.Groups[1].Value
            $anchor = ''
            if ($target -match '^(.*?)(#.*)$') { $target = $Matches[1]; $anchor = $Matches[2] }
            $absolute = [System.IO.Path]::GetFullPath((Join-Path $FromDir $target))
            $relative = [System.IO.Path]::GetRelativePath($ToDir, $absolute) -replace '\\', '/'
            "]($relative$anchor)"
        })
}

function Get-Required {
    param($Item, [string] $Key, [string] $Path)
    $value = if ($Key -like 'metadata.*') { $Item.Data['metadata'][$Key.Substring(9)] } else { $Item.Data[$Key] }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "$Path is missing $Key in its frontmatter." }
    $value
}

$generated = [ordered]@{}
$agents = foreach ($file in (Get-ChildItem -Path (Join-Path $root '.github/agents') -Filter '*.agent.md' | Sort-Object Name)) {
    $relativeSource = ".github/agents/$($file.Name)"
    $item = Read-Frontmatter -Path $file.FullName
    $name = Get-Required $item 'name' $relativeSource
    $description = Get-Required $item 'description' $relativeSource
    $tools = Get-Required $item 'metadata.claude-tools' $relativeSource
    $frontmatter = "---`nname: $name`ndescription: $(Format-Folded $description)`n"
    if ($tools -ne 'all') { $frontmatter += "tools: $tools`n" }
    $frontmatter += "---`n"
    $body = Convert-RelativeLinks -Markdown $item.Body -FromDir (Join-Path $root '.github/agents') -ToDir (Join-Path $root '.claude/agents')
    $note = "<!-- Generated from $relativeSource by $generator. Edit that file, then run the script. -->"
    $generated[".claude/agents/$name.md"] = "$frontmatter`n$note`n`n$($body.TrimEnd())`n"
    [pscustomobject]@{
        Name          = $name
        Source        = $relativeSource
        Audience      = Get-Required $item 'metadata.audience' $relativeSource
        Summary       = Get-Required $item 'metadata.summary' $relativeSource
        UserInvocable = $item.Data['user-invocable'] -ne 'false'
    }
}

$skills = foreach ($dir in (Get-ChildItem -Path (Join-Path $root '.github/skills') -Directory | Sort-Object Name)) {
    $relativeSource = ".github/skills/$($dir.Name)/SKILL.md"
    $item = Read-Frontmatter -Path (Join-Path $dir.FullName 'SKILL.md')
    $name = Get-Required $item 'name' $relativeSource
    $description = Get-Required $item 'description' $relativeSource
    $title = (Get-Culture).TextInfo.ToTitleCase(($name -replace '-', ' '))
    $generated[".claude/skills/$name/SKILL.md"] = @"
---
name: $name
description: $(Format-Folded $description)
---

<!-- Generated from $relativeSource by $generator. Edit that file, then run the script. -->

# $title (pointer)

The canonical skill content lives at [``$relativeSource``](../../../$relativeSource).

**Read that file and follow it.** This pointer exists so Claude Code can suggest the skill when it detects a relevant task. GitHub Copilot reads the canonical file directly, so both tools follow the same instructions.

"@ -replace "`r`n", "`n"
    [pscustomobject]@{
        Name     = $name
        Source   = $relativeSource
        Audience = Get-Required $item 'metadata.audience' $relativeSource
        Summary  = Get-Required $item 'metadata.summary' $relativeSource
    }
}

function Format-Cell([string] $Text) { $Text -replace '\|', '\|' -replace '<', '&lt;' -replace '>', '&gt;' }

$agentRows = foreach ($a in $agents) {
    $how = if ($a.UserInvocable) { 'Pick it in Copilot''s agent list, or ask Claude Code to use it' } else { 'Called by the other agents, or ask Claude Code to use it' }
    "| [``$($a.Name)``]($repoUrl/$($a.Source)) | $(Format-Cell $a.Audience) | $(Format-Cell $a.Summary) | $how |"
}
$skillRows = foreach ($s in $skills) {
    "| [``$($s.Name)``]($repoUrl/$($s.Source)) | $(Format-Cell $s.Audience) | $(Format-Cell $s.Summary) |"
}

$generated['website/docs/agents-and-skills.md'] = @"
---
title: 🤖 Agents and skills
description: The AI agents and skills in the Maester repository, who they are for, and how to change them.
---

{/* Generated by $generator from .github/agents and .github/skills. Edit those files, then run the script. */}

# Agents and skills

The Maester repository ships AI agents and skills that know its conventions: how a check is written,
which attributes it needs, how pull requests and issues are labelled. They work in
[GitHub Copilot](https://docs.github.com/copilot) and [Claude Code](https://docs.claude.com/en/docs/claude-code)
when you open the repository. [AGENTS.md]($repoUrl/AGENTS.md) holds the rules every agent follows.

## Agents

An agent is a role with its own instructions and tools. Ask for it by name, for example
"use maester-test-planner to plan a check for guest invite settings".

| Agent | For | What it does | How to use it |
| --- | --- | --- | --- |
$($agentRows -join "`n")

## Skills

A skill is a body of knowledge an agent loads when the task needs it. The agents above read these, and
any agent can follow them directly.

| Skill | For | What it covers |
| --- | --- | --- |
$($skillRows -join "`n")

## Changing an agent or skill

Each agent and skill has one source file, which GitHub Copilot reads:

- an agent is ``.github/agents/<name>.agent.md``
- a skill is ``.github/skills/<name>/SKILL.md``

Everything else is generated from those files by ``$generator``: the Claude Code copies under
``.claude/agents/`` and ``.claude/skills/``, and this page. Never edit the generated files.

To add or change one:

1. Edit or create the source file. Its frontmatter needs ``name`` and ``description``, and a
   ``metadata`` block with ``audience`` (who uses it) and ``summary`` (one sentence on what it does).
   An agent also needs ``metadata.claude-tools``: the Claude Code tools it may use, or ``all``.
2. Run ``./$generator``.
3. Commit the source file and the generated files together. ``powershell/tests/general/AgentFiles.Tests.ps1``
   fails the build when a generated file is out of date.
"@ -replace "`r`n", "`n"
$generated['website/docs/agents-and-skills.md'] = $generated['website/docs/agents-and-skills.md'].TrimEnd() + "`n"

# Claude Code copies whose source is gone are stale too.
$expected = [System.Collections.Generic.HashSet[string]]::new([string[]]$generated.Keys)
$orphans = @(
    Get-ChildItem -Path (Join-Path $root '.claude/agents') -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object { ".claude/agents/$($_.Name)" }
    Get-ChildItem -Path (Join-Path $root '.claude/skills') -Directory -ErrorAction SilentlyContinue | ForEach-Object { ".claude/skills/$($_.Name)/SKILL.md" }
) | Where-Object { -not $expected.Contains($_) }

$stale = @(foreach ($path in $generated.Keys) {
        $full = Join-Path $root $path
        $current = if (Test-Path $full) { (Get-Content -Path $full -Raw -Encoding utf8) -replace "`r`n", "`n" } else { $null }
        if ($current -cne $generated[$path]) { $path }
    })

if ($Check) {
    $problems = @($stale) + @($orphans | ForEach-Object { "$_ (no source file)" })
    if ($problems.Count -gt 0) {
        throw "These generated agent files are out of date: $($problems -join ', '). Run ./$generator and commit the result."
    }
    Write-Verbose 'The generated agent files are up to date.'
    return
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($path in $stale) {
    $full = Join-Path $root $path
    New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null
    [System.IO.File]::WriteAllText($full, $generated[$path], $utf8)
    Write-Verbose "Wrote $path"
}
foreach ($path in $orphans) {
    Write-Warning "$path has no source file under .github/. Delete it, or add the source file and run this script again."
}
[pscustomobject]@{ Written = $stale.Count; Orphans = $orphans.Count }

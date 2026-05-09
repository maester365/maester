<#
.SYNOPSIS
    Stamps the ModuleVersion and ConfigVersion fields at the top of a
    maester-config.json file using surgical regex replacement.

.DESCRIPTION
    Preserves the file's existing 2-space indentation and overall layout by
    avoiding a JSON round-trip. Validates the input and output are valid JSON.
    Writes UTF-8 without BOM.

    Both fields must already exist in the source file. The script does not
    insert missing fields — if either is absent, it throws and asks the
    caller to add them manually. This avoids fragile insertion logic and
    makes schema changes explicit in source control.

    ConfigVersion is a CalVer-style YYYY.MM.DD.N string derived from git
    history of the config file: YYYY.MM.DD is the date of the most recent
    commit to the file; N is the count of commits to the file on that date.
    Auto-computed when -ConfigVersion is omitted (the normal CI path).

    Requires sufficient git history to find the last commit touching the file,
    so callers should run actions/checkout with fetch-depth: 0.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $ModuleVersion,
    [Parameter()]          [string] $ConfigVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

if ([string]::IsNullOrWhiteSpace($ConfigVersion)) {
    # Resolve to a repo-relative path so git lookup works regardless of CWD
    # or whether ConfigPath was passed as relative or absolute.
    $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
    $configDir = Split-Path -Parent $resolvedConfigPath
    $repoRoot = (& git -C $configDir rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Could not determine ConfigVersion: $ConfigPath is not inside a git repository."
    }
    $repoRoot = $repoRoot.Trim()
    $repoRelative = [System.IO.Path]::GetRelativePath($repoRoot, $resolvedConfigPath).Replace('\', '/')
    $dates = @(& git -C $repoRoot log --format=%cd --date=format:%Y.%m.%d -- $repoRelative)
    if ($LASTEXITCODE -ne 0 -or $dates.Count -eq 0) {
        throw "Could not determine ConfigVersion: no git history found for $repoRelative in $repoRoot."
    }
    $lastDate = $dates[0]
    $sameDayCount = @($dates | Where-Object { $_ -eq $lastDate }).Count
    $ConfigVersion = "$lastDate.$sameDayCount"
    Write-Verbose "Computed ConfigVersion=$ConfigVersion (date $lastDate, $sameDayCount commit(s) that day)"
}

$content = Get-Content -LiteralPath $ConfigPath -Raw
try { $null = $content | ConvertFrom-Json } catch { throw "Input file is not valid JSON: $_" }

$mvLine = '"ModuleVersion": "{0}"' -f $ModuleVersion
$cvLine = '"ConfigVersion": "{0}"' -f $ConfigVersion

# Multiline mode + exact 2-space indent prefix matches only top-level keys in
# this file's formatting (top level uses 2 spaces, nested keys use 4+). This
# rules out accidental matches on a nested property of the same name.
$mvRegex = [regex]'(?m)^  "ModuleVersion"\s*:\s*"[^"]*"'
if (-not $mvRegex.IsMatch($content)) {
    throw "Required field ModuleVersion not found at the top level of $ConfigPath (must be at 2-space indent). Add `"ModuleVersion`": `"<version>`" as a top-level key before re-running."
}
$content = $mvRegex.Replace($content, ('  ' + $mvLine), 1)

$cvRegex = [regex]'(?m)^  "ConfigVersion"\s*:\s*"[^"]*"'
if (-not $cvRegex.IsMatch($content)) {
    throw "Required field ConfigVersion not found at the top level of $ConfigPath (must be at 2-space indent). Add `"ConfigVersion`": `"`" as a top-level key before re-running."
}
$content = $cvRegex.Replace($content, ('  ' + $cvLine), 1)

try { $null = $content | ConvertFrom-Json } catch { throw "Output is not valid JSON after stamping: $_" }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $ConfigPath).Path, $content, $utf8NoBom)

Write-Host "Stamped ${ConfigPath}: ModuleVersion=$ModuleVersion, ConfigVersion=$ConfigVersion"

<#
.SYNOPSIS
    Stamps the ModuleVersion and ConfigVersion fields at the top of a
    maester-config.json file.

.DESCRIPTION
    Reads and updates the JSON object directly, then writes UTF-8 without BOM.
    Uses an explicit JSON depth when writing so future nested settings are not
    truncated by the default ConvertTo-Json depth.

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

if (-not $PSBoundParameters.ContainsKey('ConfigVersion')) {
    # Resolve to a repo-relative path so git lookup works regardless of CWD
    # or whether ConfigPath was passed as relative or absolute.
    $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).ProviderPath
    $configDir = Split-Path -Parent $resolvedConfigPath
    $repoRoot = (& git -C $configDir rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Could not determine ConfigVersion: $ConfigPath is not inside a git repository."
    }
    $repoRoot = $repoRoot.Trim()
    # Compute relative path in a way that works on all .NET versions
    $repoRelative = $resolvedConfigPath -replace "^$([regex]::Escape($repoRoot))[\\/]?", ''
    $repoRelative = $repoRelative.Replace('\', '/')
    $commitTimestamps = @(& git -C $repoRoot log --format=%ct -- $repoRelative)
    if ($LASTEXITCODE -ne 0 -or $commitTimestamps.Count -eq 0) {
        throw "Could not determine ConfigVersion: no git history found for $repoRelative in $repoRoot."
    }
    $utcDates = @($commitTimestamps | ForEach-Object {
            [System.DateTimeOffset]::FromUnixTimeSeconds([long]$_).UtcDateTime.ToString('yyyy.MM.dd', [System.Globalization.CultureInfo]::InvariantCulture)
        })
    $lastDate = $utcDates[0]
    $sameDayCount = @($utcDates | Where-Object { $_ -eq $lastDate }).Count
    $ConfigVersion = "$lastDate.$sameDayCount"
    Write-Verbose "Computed ConfigVersion=$ConfigVersion (date $lastDate, $sameDayCount commit(s) that day)"
}

$content = Get-Content -LiteralPath $ConfigPath -Raw
try {
    $config = $content | ConvertFrom-Json
} catch {
    throw "Input file is not valid JSON: $_"
}

if (-not ($config.PSObject.Properties.Name -contains 'ModuleVersion')) {
    throw "Required field ModuleVersion not found in $ConfigPath. Add `"ModuleVersion`": `"<version>`" as a top-level key before re-running."
}

if (-not ($config.PSObject.Properties.Name -contains 'ConfigVersion')) {
    throw "Required field ConfigVersion not found in $ConfigPath. Add `"ConfigVersion`": `"`" as a top-level key before re-running."
}

$config.ModuleVersion = $ModuleVersion
$config.ConfigVersion = $ConfigVersion
$updatedContent = $config | ConvertTo-Json -Depth 10 -WarningAction Stop

try { $null = $updatedContent | ConvertFrom-Json } catch { throw "Output is not valid JSON after stamping: $_" }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$resolvedOutputPath = (Resolve-Path -LiteralPath $ConfigPath).ProviderPath
[System.IO.File]::WriteAllText($resolvedOutputPath, $updatedContent, $utf8NoBom)

Write-Host "Stamped ${ConfigPath}: ModuleVersion=$ModuleVersion, ConfigVersion=$ConfigVersion"

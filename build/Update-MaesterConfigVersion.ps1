<#
.SYNOPSIS
    Stamps the ModuleVersion and ConfigVersion fields at the top of a
    maester-config.json file using surgical regex replacement.

.DESCRIPTION
    Preserves the file's existing 2-space indentation and overall layout by
    avoiding a JSON round-trip. Validates the input and output are valid JSON.
    Writes UTF-8 without BOM.

    Inserts either field if absent so the script also works on a config file
    that has not yet been migrated to include these fields.

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
    $dates = @(git log --format=%cd --date=format:%Y.%m.%d -- $ConfigPath)
    if ($LASTEXITCODE -ne 0 -or $dates.Count -eq 0) {
        throw "Could not determine ConfigVersion: no git history found for $ConfigPath"
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

$mvRegex = [regex]'"ModuleVersion"\s*:\s*"[^"]*"'
if ($mvRegex.IsMatch($content)) {
    $content = $mvRegex.Replace($content, $mvLine, 1)
} else {
    # Insert as first key after the opening brace.
    $content = $content -replace '^\{\s*', "{`n  $mvLine,`n  "
}

$cvRegex = [regex]'"ConfigVersion"\s*:\s*"[^"]*"'
if ($cvRegex.IsMatch($content)) {
    $content = $cvRegex.Replace($content, $cvLine, 1)
} else {
    # Insert immediately after the ModuleVersion line.
    $anchorRegex = [regex]([regex]::Escape($mvLine) + ',')
    $content = $anchorRegex.Replace($content, "$mvLine,`n  $cvLine,", 1)
}

try { $null = $content | ConvertFrom-Json } catch { throw "Output is not valid JSON after stamping: $_" }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $ConfigPath).Path, $content, $utf8NoBom)

Write-Host "Stamped ${ConfigPath}: ModuleVersion=$ModuleVersion, ConfigVersion=$ConfigVersion"

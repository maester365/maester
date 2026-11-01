<#
    .SYNOPSIS
    Updates the checked-in snapshot of Microsoft Graph permissions blocked for agent identities.

    .DESCRIPTION
    Downloads Microsoft's agentid-platform-overview.md from the public docs repo,
    parses the "Microsoft Graph permissions blocked for agents" table, validates the
    result, and writes a JSON snapshot into the module's internal generated folder.
    The update-agent-blocked-permissions workflow runs this monthly and raises a pull
    request when the table changes.
    For reproducibility, pass a commit-pinned raw URL with -SourceUrl.

    .EXAMPLE
    ./build/Update-MtAgentBlockedPermissions.ps1
#>

[CmdletBinding()]
param (
    # Path to the generated JSON snapshot.
    [string] $SnapshotPath = "$PSScriptRoot/../powershell/internal/generated/AgentBlockedPermissions.json",

    # Raw URL of Microsoft's agent ID platform overview page.
    [string] $SourceUrl = 'https://raw.githubusercontent.com/microsoftgraph/microsoft-graph-docs-contrib/main/api-reference/v1.0/resources/agentid-platform-overview.md',

    # Minimum expected row count. The table has 57 rows today.
    [int] $MinimumRowCount = 50
)

$ErrorActionPreference = 'Stop'

# --- Download ---

Write-Verbose "Downloading agent blocked permissions from $SourceUrl..."
try {
    $response = Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing -ErrorAction Stop
} catch {
    throw "Failed to download agent permissions doc from $SourceUrl. Error: $_"
}

if ($response.StatusCode -ne 200) {
    throw "Unexpected HTTP status code $($response.StatusCode) from $SourceUrl"
}

$content = $response.Content
if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 1000) {
    throw "Downloaded content appears empty or too short ($($content.Length) chars). Aborting."
}

# --- Find the table ---

$lines = $content -split "`n"
$tableStartIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*Permission name\s*\|') {
        $tableStartIndex = $i
        break
    }
}

if ($tableStartIndex -lt 0) {
    throw "Could not find the 'Permission name' table header in the downloaded markdown. Microsoft may have renamed or moved the section."
}

# --- Parse rows ---

$permissions = [System.Collections.Generic.List[hashtable]]::new()

# Skip the header row and the separator row (the |---|---|---| line)
for ($i = $tableStartIndex + 2; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()

    # Stop at the first non-table line
    if (-not $line.StartsWith('|')) { break }

    # Split on | and trim. The split gives us empty strings at the start and end.
    $cells = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    if ($cells.Count -lt 3) {
        throw "Malformed row (expected 3 columns): $line"
        continue
    }

    # Column 0: permission name (may be a markdown link like [Name](url))
    $permName = $cells[0]
    if ($permName -match '^\[([^\]]+)\]') {
        $permName = $Matches[1]
    }
    $permName = $permName.Trim()

    if ([string]::IsNullOrWhiteSpace($permName)) {
        throw "Empty permission name in row: $line"
        continue
    }

    # Column 1: Delegated, Column 2: Application
    # The values use symbols, not words, but handle both
    $delegated = if ($cells[1] -match [char]0x274C) { $true } elseif ($cells[1] -match [char]0x2796) { $false } else { throw "Unexpected Delegated value $($cells[1]) for $permName" }
    $application = if ($cells[2] -match [char]0x274C) { $true } elseif ($cells[2] -match [char]0x2796) { $false } else { throw "Unexpected Application value $($cells[2]) for $permName" }

    $permissions.Add(@{
        Permission  = $permName
        Delegated   = $delegated
        Application = $application
    })
}

# --- Validate ---

if ($permissions.Count -lt $MinimumRowCount) {
    throw "Only $($permissions.Count) permissions parsed; expected at least $MinimumRowCount. The table format may have changed."
}

Write-Verbose "Parsed $($permissions.Count) blocked permissions."

# --- Hash the source for traceability ---

$sourceBytes = [System.Text.Encoding]::UTF8.GetBytes(($lines[$tableStartIndex..($i - 1)] -join "`n"))
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $sourceHash = (-join ($sha256.ComputeHash($sourceBytes) | ForEach-Object { $_.ToString('x2') }))
} finally {
    $sha256.Dispose()
}

# --- Build output ---
# Note: GeneratedAt is metadata only and is excluded from the diff-detection
# input. The workflow's git-diff step compares the Permissions array, Count,
# SourceUrl, and SourceSha256, which change only when Microsoft's table does.

$output = [ordered]@{
    SourceUrl    = $SourceUrl
    SourceSha256 = $sourceHash
    Count        = $permissions.Count
    Permissions  = @($permissions | Sort-Object { $_.Permission } | ForEach-Object {
        [ordered]@{
            Permission  = $_.Permission
            Delegated   = $_.Delegated
            Application = $_.Application
        }
    })
}

# --- Write ---

$resolvedPath = $SnapshotPath
if (Test-Path -LiteralPath $SnapshotPath) {
    $resolvedPath = (Resolve-Path -LiteralPath $SnapshotPath).ProviderPath
} else {
    $parent = Split-Path -Parent $SnapshotPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $resolvedPath = [System.IO.Path]::GetFullPath($SnapshotPath)
}

$json = $output | ConvertTo-Json -Depth 5
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resolvedPath, $json + "`n", $utf8NoBom)

Write-Verbose "Updated $resolvedPath with $($permissions.Count) permissions; source SHA-256: $sourceHash"

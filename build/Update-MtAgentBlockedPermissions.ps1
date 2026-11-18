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

    # Fewest rows accepted when there is no earlier snapshot to compare with. The table has 59 rows today.
    [int] $MinimumRowCount = 50,

    # Most permissions that may drop out of the table in one update, as a percentage of the earlier snapshot.
    # A larger drop is more likely a broken parse or a bad edit upstream than a real change, so the script
    # stops. After checking Microsoft's table, run it again with -AllowLargeRemoval.
    [ValidateRange(0, 100)]
    [int] $MaximumRemovedPercent = 20,

    # Accept more removals than -MaximumRemovedPercent allows. Use it only after checking Microsoft's table.
    [switch] $AllowLargeRemoval
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
$headerIndexes = @(for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*Permission name\s*\|') { $i }
})

if ($headerIndexes.Count -eq 0) {
    throw "Could not find the 'Permission name' table header in the downloaded markdown. Microsoft may have renamed or moved the section."
}
if ($headerIndexes.Count -gt 1) {
    throw "Found $($headerIndexes.Count) tables with a 'Permission name' header (lines $(($headerIndexes | ForEach-Object { $_ + 1 }) -join ', ')); expected one. Check which table lists the blocked permissions."
}
$tableStartIndex = $headerIndexes[0]

# Rows are read by column position, so check the column names and their order first.
# A swapped or added column would otherwise put the wrong values in the snapshot.
$expectedHeader = @('Permission name', 'Delegated', 'Application')
$headerCells = @($lines[$tableStartIndex].Trim() -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if (-not [string]::Equals(($headerCells -join ' | '), ($expectedHeader -join ' | '), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unexpected table columns '$($headerCells -join ' | ')'; expected '$($expectedHeader -join ' | ')'. Microsoft may have added, removed or reordered a column."
}
if ($tableStartIndex + 1 -ge $lines.Count -or $lines[$tableStartIndex + 1].Trim() -notmatch '^\|(\s*:?-+:?\s*\|){3}$') {
    throw "Expected a three-column separator row (|---|---|---|) after the table header."
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

    if ($cells.Count -ne 3) {
        throw "Malformed row (expected 3 columns, found $($cells.Count)): $line"
    }

    # Column 0: permission name (may be a markdown link like [Name](url))
    $permName = $cells[0]
    if ($permName -match '^\[([^\]]+)\]') {
        $permName = $Matches[1]
    }
    $permName = $permName.Trim()

    if ([string]::IsNullOrWhiteSpace($permName)) {
        throw "Empty permission name in row: $line"
    }

    # Graph permission names use only letters, digits, '.', '_' and '-', as in Microsoft's Graph
    # permissions reference. Anything else (a space, a backtick, an invisible character) would put a
    # name in the snapshot that is not the real permission name. A space breaks the drift test's
    # match; an invisible character does not even show, because PowerShell's -eq ignores it. The
    # check is case-sensitive (-cnotmatch) because a case-insensitive [A-Za-z] also accepts the
    # Kelvin sign.
    if ($permName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z') {
        throw "Unexpected characters in permission name '$permName' in row: $line"
    }

    # Column 1: Delegated, column 2: Application. Each cell must hold exactly one symbol:
    # U+274C (cross mark) means blocked, U+2796 (heavy minus sign) means not blocked. A trailing
    # U+FE0F (emoji presentation selector) does not change the meaning, so it is removed first.
    # Compared ordinally: -ceq ignores U+FE0F and zero-width characters on some machines and not on
    # others (not when .NET runs in invariant globalization mode).
    $delegated, $application = foreach ($column in 1, 2) {
        $value = $cells[$column].Replace([string][char]0xFE0F, '').Trim()
        if ([string]::Equals($value, [string][char]0x274C, [StringComparison]::Ordinal)) { $true }
        elseif ([string]::Equals($value, [string][char]0x2796, [StringComparison]::Ordinal)) { $false }
        else { throw "Unexpected $($expectedHeader[$column]) value '$($cells[$column])' for $permName" }
    }

    $permissions.Add(@{
        Permission  = $permName
        Delegated   = $delegated
        Application = $application
    })
}

# --- Validate ---

# Compare with the snapshot already checked in. A fixed minimum stops a real shrink by Microsoft just as it
# stops a broken parse, so the guard is relative to the earlier snapshot: too many permissions dropping out at
# once stops the update. With no earlier snapshot (the first run), the fixed minimum still applies.
$previousNames = @()
if (Test-Path -LiteralPath $SnapshotPath) {
    try {
        $previousSnapshot = Get-Content -LiteralPath $SnapshotPath -Raw | ConvertFrom-Json
    } catch {
        throw "Could not read the existing snapshot at $SnapshotPath to compare with. $($_.Exception.Message)"
    }
    $previousNames = @($previousSnapshot.Permissions | ForEach-Object { [string]$_.Permission })
}

if ($previousNames.Count -eq 0) {
    if ($permissions.Count -lt $MinimumRowCount) {
        throw "Only $($permissions.Count) permissions parsed; expected at least $MinimumRowCount. The table format may have changed."
    }
} else {
    $currentNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $permissions) { [void]$currentNames.Add($p.Permission) }
    $removedNames = @($previousNames | Where-Object { -not $currentNames.Contains($_) })
    $allowedRemovals = [math]::Floor($previousNames.Count * $MaximumRemovedPercent / 100)
    if ($removedNames.Count -gt $allowedRemovals -and -not $AllowLargeRemoval) {
        throw ("$($removedNames.Count) of the $($previousNames.Count) permissions in the current snapshot are no longer in the table, " +
            "more than the $allowedRemovals ($MaximumRemovedPercent%) allowed in one update. That is more likely a broken parse or a bad edit " +
            "upstream than a real change. Check the source; if the removals are real, run again with -AllowLargeRemoval. " +
            "No longer listed: $($removedNames -join ', ')")
    }
    Write-Verbose "$($removedNames.Count) permission(s) dropped out of the table since the last snapshot (at most $allowedRemovals allowed)."
}

# A name listed twice makes the snapshot ambiguous (which row's values apply?), and the ordinal
# sort below does not keep equal names in a fixed order. Stop instead of writing either.
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($p in $permissions) {
    if (-not $seen.Add($p.Permission)) {
        throw "Permission '$($p.Permission)' appears more than once in the table. Check the source before updating the snapshot."
    }
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
# The snapshot holds no timestamp, so the workflow's git diff is non-empty only when
# Microsoft's table or SourceUrl changes.

# Sort by ordinal (character code) comparison. Sort-Object compares by the machine's culture,
# which orders some names differently from one machine to another and would make the
# snapshot change without any change in Microsoft's table.
$sorted = [System.Collections.Generic.List[hashtable]]::new($permissions)
$sorted.Sort([System.Comparison[hashtable]] { param($a, $b) [string]::CompareOrdinal($a.Permission, $b.Permission) })

$output = [ordered]@{
    SourceUrl    = $SourceUrl
    SourceSha256 = $sourceHash
    Count        = $permissions.Count
    Permissions  = @($sorted | ForEach-Object {
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

<#
    .Synopsis
    Updates the auto-generated Entra ID role definitions in the Maester PowerShell module.

    .DESCRIPTION
    Downloads the Microsoft Entra built-in roles permissions reference Markdown from GitHub (public, no auth required),
    parses role names, GUIDs, and privileged indicators, then updates:
    - powershell/internal/Get-MtRoleInfo.ps1 ($script:MtRoles hashtable with MtRoleDefinition objects)

    Includes safeguards against corrupted data, missing roles, and structural regressions.

    .EXAMPLE
    ./build/Update-MtRoleDefinitions.ps1
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple role definitions.')]
param (
    # Path to Get-MtRoleInfo.ps1
    [string] $RoleInfoPath = "$PSScriptRoot/../powershell/internal/Get-MtRoleInfo.ps1",

    # URL to fetch role definitions from (raw Markdown from GitHub)
    [string] $SourceUrl = 'https://raw.githubusercontent.com/MicrosoftDocs/entra-docs/main/docs/identity/role-based-access-control/permissions-reference.md',

    # Minimum number of roles expected (safeguard against partial data)
    [int] $MinimumRoleCount = 80
)

$ErrorActionPreference = 'Stop'

#region Helper functions

function Get-RoleDataFromMarkdown {
    <#
    .SYNOPSIS
    Parses the permissions reference Markdown "All roles" table and extracts role definitions.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory)]
        [string] $Markdown
    )
    #region Parsing logic only grabbing the table data under "All roles"
    $roles = [System.Collections.Generic.List[hashtable]]::new()
    $guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

    # Extract just the "All roles" section via substring — avoids iterating the entire document
    $sectionStart = [regex]::Match($Markdown, '(?m)^#+\s+All roles')
    if (-not $sectionStart.Success) {
        throw "Could not find 'All roles' section in the Markdown document. Document structure may have changed."
    }

    $contentAfterHeading = $Markdown.Substring($sectionStart.Index + $sectionStart.Length)
    $nextHeading = [regex]::Match($contentAfterHeading, '(?m)^#+\s')
    $sectionBody = if ($nextHeading.Success) {
        $contentAfterHeading.Substring(0, $nextHeading.Index)
    } else {
        $contentAfterHeading
    }

    # Strip blockquote prefixes only from table rows (lines where '>' precedes a '|').
    # GFM allows up to 3 spaces of indentation before '>'; the lookahead (?=\s*\|) ensures
    # non-table blockquote lines (e.g. '> [!div ...]' directives) are left intact.
    $sectionBody = [regex]::Replace($sectionBody, '(?m)^ {0,3}>\s?(?=\s*\|)', '')

    # Validate that the section contains a Markdown table header separator row with at least 3 columns
    $allSectionLines = $($sectionBody -split '\r?\n') | Where-Object { $_ -ne '' }
    $separatorLine = $allSectionLines | Where-Object { $_ -match '^\s*\|[\s\-|]+\|\s*$' -and $_ -match '\-{3,}' } | Select-Object -First 1
    if (-not $separatorLine) {
        throw "Could not find a Markdown table header separator row in the 'All roles' section. Document structure may have changed."
    }
    $separatorColCount = ($separatorLine -split '\|' | Where-Object { $_ -match '\S' }).Count
    if ($separatorColCount -lt 3) {
        throw "Table header has only $separatorColCount column(s); expected at least 3 (Role, Description, ID). Document structure may have changed."
    }

    $lines = $($sectionBody -split '\r?\n').trim() | Where-Object { $_ -ne '' }
    $lines = $lines | Where-Object { $_ -match $guidPattern }
    #endregion Parsing logic only grabbing the table data under "All roles"

    foreach ($line in $lines) {

        <#
        Just providing some context/clarity on how our data looks at this point:
        $line looks like this at this point (blockquote prefixes have already been stripped above):
        | [Agent ID Administrator](#agent-id-administrator) | Manage all aspects of agents in a tenant including identity lifecycle operations for agent blueprints, agent service principals, agent identities, and agentic users.<br/>[![Privileged label icon.](./media/permissions-reference/privileged-label.png)](privileged-roles-permissions.md) | db506228-d27e-4b7d-95e5-295956d6615f |
        #>
        $entry = $line.Split('|')
        if ($entry.Count -lt 4) { continue }
        # sample: [Agent ID Administrator](#agent-id-administrator)
        $displayName = $entry[1]
        # sample: Manage all aspects of agents in a tenant including identity lifecycle operations for agent blueprints, agent service principals, agent identities, and agentic users.<br/>[![Privileged label icon.](./media/permissions-reference/privileged-label.png)](privileged-roles-permissions.md)
        $roleDescription = $entry[2].Trim()
        # sample: db506228-d27e-4b7d-95e5-295956d6615f
        $roleGuid = $entry[3].Trim().ToLower()

        # Cleanup roleName and roleDescription from roleDescription we also need to extract if the role is privileged or not (if it contains the privileged label icon)
        # Extract display name from Markdown link [Display Name](#anchor)
        $displayNameMatch = [regex]::Match($displayName, '\[([^\]]+)\]')
        if (-not $displayNameMatch.Success) {
            continue
        }
        $displayName = $displayNameMatch.Groups[1].Value.Trim().Replace('[', ' ').Replace(']', ' ')

        # The description may contain the privileged label icon markdown if it's a privileged role, we want to check for that and also remove it from the description
        $isPrivileged = $roleDescription -match 'Privileged label icon'

        # Leaving description here for now if we want it in the future we just need to split on new lines html
        #$description = $roleDescription.Split('<br/>')[0].Trim()

        # Convert display name to PascalCase identifier (remove spaces, special characters)
        $roleName = $displayName -replace '[^a-zA-Z0-9 ]', ''
        $roleName = $roleName -replace '\s+', ' '
        $words = $roleName.Trim().Split(' ')
        $roleName = ($words | ForEach-Object {
                if ($_.Length -gt 0) {
                    $_.Substring(0, 1).ToUpper() + $_.Substring(1)
                }
            }) -join ''

        if ([string]::IsNullOrWhiteSpace($roleName)) { continue }

        $roles.Add(@{
                Name         = $roleName
                Id           = $roleGuid
                IsPrivileged = $isPrivileged
                DisplayName  = $displayName
            })
    }

    return $roles
}

function Test-KnownRolesPresent {
    <#
    .SYNOPSIS
    Verifies that critical well-known roles are present in the parsed data.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]] $Roles
    )

    $knownRoles = @{
        'GlobalAdministrator'   = '62e90394-69f5-4237-9190-012177145e10'
        'SecurityAdministrator' = '194ae4cb-b126-40b2-bd5b-6091b380977d'
        'UserAdministrator'     = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
        'HelpdeskAdministrator' = '729827e3-9c14-49f7-bb1b-9608f156bbb8'
        'ExchangeAdministrator' = '29232cdf-9323-42fd-ade2-1d097af3e4de'
    }

    $allPresent = $true
    foreach ($entry in $knownRoles.GetEnumerator()) {
        $match = $Roles | Where-Object { $_.Name -eq $entry.Key -and $_.Id -eq $entry.Value }
        if (-not $match) {
            Write-Warning "Known role '$($entry.Key)' ($($entry.Value)) not found in parsed data."
            $allPresent = $false
        }
    }

    return $allPresent
}

function Test-AllGuidsValid {
    <#
    .SYNOPSIS
    Validates that all role IDs are valid GUIDs.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]] $Roles
    )

    $guidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    $allValid = $true
    foreach ($role in $Roles) {
        if ($role.Id -notmatch $guidPattern) {
            Write-Warning "Invalid GUID '$($role.Id)' for role '$($role.Name)'."
            $allValid = $false
        }
    }
    return $allValid
}

function Get-ExistingRoles {
    <#
    .SYNOPSIS
    Extracts existing role entries from the current Get-MtRoleInfo.ps1 hashtable.
    Returns roles not found in the new data (system/implicit roles to preserve).
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory)]
        [string] $FileContent,

        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]] $NewRoles
    )

    $preservedRoles = [System.Collections.Generic.List[hashtable]]::new()
    $newRoleNames = $NewRoles | ForEach-Object { $_.Name }
    $newRoleGuids = $NewRoles | ForEach-Object { $_.Id }

    # Parse existing hashtable entries: 'RoleName' = [MtRoleDefinition]::new('guid', $true/$false)
    $entryPattern = '''([A-Za-z0-9]+)''\s*=\s*\[MtRoleDefinition\]::new\(''([0-9a-f-]+)'',\s*\$(true|false)\)'
    $existingEntries = [regex]::Matches($FileContent, $entryPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($entry in $existingEntries) {
        $name = $entry.Groups[1].Value
        if ($name -in $newRoleNames) { continue }

        $guid = $entry.Groups[2].Value
        $guid = $guid.ToLower()
        # Skip if this GUID is already covered by a renamed role in the new data.
        # Example: 'AzureADJoinedDeviceLocalAdministrator' was renamed to
        # 'MicrosoftEntraJoinedDeviceLocalAdministrator' in the public docs.
        # Preserving the old name would create two hashtable keys for the same GUID.
        if ($guid -in $newRoleGuids) {
            Write-Verbose "Skipping preserved role '$name' ($guid) - GUID is already present under a new name in the updated data."
            continue
        }

        $isPriv = if ($entry.Groups[3].Value -eq 'true') { $true } else { $false }

        $preservedRoles.Add(@{
                Name         = $name
                Id           = $guid
                IsPrivileged = $isPriv
                DisplayName  = $name
            })
    }

    return $preservedRoles
}

function Update-FileSection {
    <#
    .SYNOPSIS
    Replaces content between delimiter markers in a file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string] $BeginMarker,

        [Parameter(Mandatory)]
        [string] $EndMarker,

        [Parameter(Mandatory)]
        [string] $NewContent
    )

    $content = Get-Content -Path $FilePath -Raw
    if ($content -notmatch [regex]::Escape($BeginMarker)) {
        throw "Begin marker '$BeginMarker' not found in $FilePath"
    }
    if ($content -notmatch [regex]::Escape($EndMarker)) {
        throw "End marker '$EndMarker' not found in $FilePath"
    }

    $pattern = "(?s)($([regex]::Escape($BeginMarker)))(.*?)($([regex]::Escape($EndMarker)))"
    $replacement = "`$1`n$NewContent`n    `$3"
    $updatedContent = [regex]::Replace($content, $pattern, $replacement)
    # Use [System.IO.File]::WriteAllText with explicit UTF-8-with-BOM encoder for PS 5.1/7 compatibility.
    # Set-Content -Encoding utf8BOM is PS 7+ only and fails on Windows PowerShell 5.1.
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText((Resolve-Path $FilePath).ProviderPath, $updatedContent, $utf8Bom)
}

#endregion

#region Main execution

Write-Host 'Fetching role definitions from GitHub...' -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing -ErrorAction Stop
} catch {
    throw "Failed to download role definitions from $SourceUrl. Error: $_"
}

if ($response.StatusCode -ne 200) {
    throw "Unexpected HTTP status code $($response.StatusCode) from $SourceUrl"
}

$markdown = $response.Content
if ([string]::IsNullOrWhiteSpace($markdown) -or $markdown.Length -lt 10000) {
    throw "Downloaded content appears empty or too short ($($markdown.Length) chars). Aborting."
}

Write-Host 'Parsing role definitions from Markdown...' -ForegroundColor Cyan
$roles = Get-RoleDataFromMarkdown -Markdown $markdown

# Deduplicate by name (keep first occurrence)
$seen = @{}
$uniqueRoles = [System.Collections.Generic.List[hashtable]]::new()
foreach ($role in $roles) {
    if (-not $seen.ContainsKey($role.Name)) {
        $seen[$role.Name] = $true
        $uniqueRoles.Add($role)
    }
}
$roles = $uniqueRoles

Write-Host "Found $($roles.Count) role definitions." -ForegroundColor Cyan

# Safeguard: minimum role count
if ($roles.Count -lt $MinimumRoleCount) {
    throw "Only $($roles.Count) roles found, expected at least $MinimumRoleCount. Possible parsing issue."
}

# Safeguard: validate all GUIDs
if (-not (Test-AllGuidsValid -Roles $roles)) {
    throw 'One or more role IDs are not valid GUIDs. Aborting.'
}

# Safeguard: spot-check known roles
if (-not (Test-KnownRolesPresent -Roles $roles)) {
    throw 'One or more known roles are missing from the parsed data. Aborting.'
}

# Merge: preserve existing roles not found in the public docs (system/implicit roles)
$roleInfoContent = Get-Content -Path $RoleInfoPath -Raw
$preservedRoles = Get-ExistingRoles -FileContent $roleInfoContent -NewRoles $roles
if ($preservedRoles.Count -gt 0) {
    Write-Host "Preserving $($preservedRoles.Count) existing roles not in public docs: $($preservedRoles.Name -join ', ')" -ForegroundColor Yellow
    foreach ($preserved in $preservedRoles) {
        $roles.Add($preserved)
    }
}

# Safeguard: if more than 20% of existing roles would be new preservations, something may be wrong
$existingNames = [regex]::Matches($roleInfoContent, "'([A-Za-z0-9]+)'\s*=") |
    ForEach-Object { $_.Groups[1].Value }
if ($existingNames.Count -gt 0 -and $preservedRoles.Count -gt ($existingNames.Count * 0.2)) {
    throw "Too many existing roles ($($preservedRoles.Count) of $($existingNames.Count)) not found in public docs. Possible parsing issue."
}

# Safeguard: max GUID change rate (no more than 10% of existing role->GUID pairs may change)
$existingRoleGuids = @{}
$guidEntryPattern = "'([A-Za-z0-9]+)'\s*=\s*\[MtRoleDefinition\]::new\('([0-9a-f-]+)'"
[regex]::Matches($roleInfoContent, $guidEntryPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) |
    ForEach-Object { $existingRoleGuids[$_.Groups[1].Value] = $_.Groups[2].Value.ToLower() }
$newRoleGuidMap = @{}
foreach ($r in $roles) { $newRoleGuidMap[$r.Name] = $r.Id }
$changedGuidCount = 0
foreach ($kv in $existingRoleGuids.GetEnumerator()) {
    if ($newRoleGuidMap.ContainsKey($kv.Key) -and $newRoleGuidMap[$kv.Key] -ne $kv.Value) {
        $changedGuidCount++
    }
}
$maxAllowedGuidChanges = [Math]::Max(1, [Math]::Floor($existingRoleGuids.Count * 0.10))
if ($existingRoleGuids.Count -gt 0 -and $changedGuidCount -gt $maxAllowedGuidChanges) {
    throw "GUID change rate too high: $changedGuidCount role(s) have different GUIDs than the existing file (max allowed: $maxAllowedGuidChanges / 10%). Possible document reorganization or source compromise."
}

# Safeguard: max privileged-flag change rate (no more than 10 roles may change privilege classification)
$existingPrivCount = ([regex]::Matches($roleInfoContent, '\$true\)')).Count
$newPrivCount = ($roles | Where-Object { $_.IsPrivileged }).Count
$privChange = [Math]::Abs($newPrivCount - $existingPrivCount)
if ($existingPrivCount -gt 0 -and $privChange -gt 10) {
    throw "Privileged role count changed by $privChange (from $existingPrivCount to $newPrivCount). Expected change of at most 10. Possible privilege classification drift."
}

# Sort roles alphabetically
$roles = $roles | Sort-Object { $_.Name }

Write-Host 'Generating hashtable entries...' -ForegroundColor Cyan

# Generate Get-MtRoleInfo hashtable entries
$hashtableEntries = $roles | ForEach-Object {
    $privStr = if ($_.IsPrivileged) { '$true' } else { '$false' }
    "    '$($_.Name)' = [MtRoleDefinition]::new('$($_.Id)', $privStr)"
}
$hashtableBlock = $hashtableEntries -join "`n"

# Update Get-MtRoleInfo.ps1
Write-Host "Updating $RoleInfoPath..." -ForegroundColor Cyan
Update-FileSection -FilePath $RoleInfoPath `
    -BeginMarker '# BEGIN AUTO-GENERATED ROLE DEFINITIONS' `
    -EndMarker '# END AUTO-GENERATED ROLE DEFINITIONS' `
    -NewContent $hashtableBlock

# Summary
$privilegedCount = ($roles | Where-Object { $_.IsPrivileged }).Count
Write-Host ''
Write-Host 'Update complete!' -ForegroundColor Green
Write-Host "  Total roles: $($roles.Count)"
Write-Host "  Privileged:  $privilegedCount"
Write-Host "  Standard:    $($roles.Count - $privilegedCount)"
if ($preservedRoles.Count -gt 0) {
    Write-Host "  Preserved:   $($preservedRoles.Count) (system/implicit roles not in public docs)"
}

# Report new roles (roles in new data that weren't in the old file)
$newNames = $roles | ForEach-Object { $_.Name }
$addedRoles = $newNames | Where-Object { $_ -notin $existingNames }
if ($addedRoles) {
    Write-Host "  New roles:   $($addedRoles -join ', ')" -ForegroundColor Yellow
}

#endregion

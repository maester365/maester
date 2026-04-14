<#
    .Synopsis
    Updates the auto-generated Entra ID role definitions in the Maester PowerShell module.

    .DESCRIPTION
    Downloads the Microsoft Entra built-in roles permissions reference page (public, no auth required),
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

    # URL to fetch role definitions from
    [string] $SourceUrl = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference',

    # Minimum number of roles expected (safeguard against partial data)
    [int] $MinimumRoleCount = 80
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper functions

function Get-RoleDataFromHtml {
    <#
    .SYNOPSIS
    Parses the permissions reference HTML page "All roles" table and extracts role definitions.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory)]
        [string] $Html
    )

    $roles = [System.Collections.Generic.List[hashtable]]::new()
    $guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

    # Locate the "All roles" table — it's the first <table> after the h2 with id="all-roles"
    $allRolesIdx = $Html.IndexOf('id="all-roles"')
    if ($allRolesIdx -lt 0) {
        throw "Could not find 'all-roles' section in the HTML page. Page structure may have changed."
    }

    $tableStart = $Html.IndexOf('<table', $allRolesIdx)
    $tableEnd = $Html.IndexOf('</table>', $tableStart)
    if ($tableStart -lt 0 -or $tableEnd -lt 0) {
        throw 'Could not find the All Roles table in the HTML page.'
    }

    $tableHtml = $Html.Substring($tableStart, $tableEnd - $tableStart + 8)

    # Extract each <tr> row
    $rowMatches = [regex]::Matches($tableHtml, '(?s)<tr>(.*?)</tr>')

    foreach ($rowMatch in $rowMatches) {
        $row = $rowMatch.Groups[1].Value
        $cells = [regex]::Matches($row, '(?s)<td[^>]*>(.*?)</td>')
        if ($cells.Count -lt 3) { continue }

        $nameCell = $cells[0].Groups[1].Value
        $descCell = $cells[1].Groups[1].Value
        $guidCell = $cells[2].Groups[1].Value

        # Extract display name from the link text
        $nameMatch = [regex]::Match($nameCell, '>([^<]+)</a>')
        if (-not $nameMatch.Success) { continue }
        $displayName = $nameMatch.Groups[1].Value.Trim()

        # Extract GUID from the third cell
        $guidMatch = [regex]::Match($guidCell, $guidPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $guidMatch.Success) { continue }
        $roleGuid = $guidMatch.Value.ToLower()

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

        # Check for privileged indicator — the img alt text "Privileged label icon."
        $isPrivileged = $descCell -match 'Privileged label icon'

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

    # Parse existing hashtable entries: 'RoleName' = [MtRoleDefinition]::new('guid', $true/$false)
    $entryPattern = '''([A-Za-z0-9]+)''\s*=\s*\[MtRoleDefinition\]::new\(''([0-9a-f-]+)'',\s*\$(true|false)\)'
    $existingEntries = [regex]::Matches($FileContent, $entryPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($entry in $existingEntries) {
        $name = $entry.Groups[1].Value
        if ($name -in $newRoleNames) { continue }

        $guid = $entry.Groups[2].Value
        $isPriv = if ($entry.Groups[3].Value -eq 'true') { $true } else { $false }

        $preservedRoles.Add(@{
                Name         = $name
                Id           = $guid.ToLower()
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
    Set-Content -Path $FilePath -Value $updatedContent -NoNewline
}

#endregion

#region Main execution

Write-Host 'Fetching role definitions from Microsoft Learn...' -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing -ErrorAction Stop
} catch {
    throw "Failed to download role definitions from $SourceUrl. Error: $_"
}

if ($response.StatusCode -ne 200) {
    throw "Unexpected HTTP status code $($response.StatusCode) from $SourceUrl"
}

$html = $response.Content
if ([string]::IsNullOrWhiteSpace($html) -or $html.Length -lt 10000) {
    throw "Downloaded content appears empty or too short ($($html.Length) chars). Aborting."
}

Write-Host 'Parsing role definitions from HTML...' -ForegroundColor Cyan
$roles = Get-RoleDataFromHtml -Html $html

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

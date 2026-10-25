#Requires -Version 7.0
<#
.SYNOPSIS
    Generates synthetic AD objects with diverse DACLs for scaling tests.

.DESCRIPTION
    Creates OUs, groups, and users using System.DirectoryServices (no RSAT).
    Applies varied permission patterns to generate realistic ACE diversity
    for testing the DACL collector's incremental progress reporting.

.PARAMETER DomainDN
    The domain distinguished name (e.g., "DC=contoso,DC=com").

.PARAMETER OuCount
    Number of organizational units to create.

.PARAMETER GroupsPerOu
    Number of groups per OU.

.PARAMETER UsersPerGroup
    Number of users per group.

.PARAMETER Credential
    PSCredential for binding to the directory. If omitted, uses current process credentials.

.PARAMETER Server
    Target domain controller. Defaults to the domain DN host.

.PARAMETER Cleanup
    Remove all previously created synthetic objects before creating new ones.

.EXAMPLE
    # Generate 10 OUs × 5 groups × 10 users = 500 users + 50 groups + 10 OUs
    ./New-MtLabSyntheticObjects.ps1 -DomainDN 'DC=contoso,DC=com' -OuCount 10 -GroupsPerOu 5 -UsersPerGroup 10

.EXAMPLE
    # Quick smoke test: 2 OUs × 2 groups × 5 users
    ./New-MtLabSyntheticObjects.ps1 -DomainDN 'DC=contoso,DC=com' -OuCount 2 -GroupsPerOu 2 -UsersPerGroup 5

.EXAMPLE
    # Clean up everything created by this script
    ./New-MtLabSyntheticObjects.ps1 -DomainDN 'DC=contoso,DC=com' -Cleanup
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$DomainDN,

    [int]$OuCount = 10,
    [int]$GroupsPerOu = 5,
    [int]$UsersPerGroup = 10,

    [pscredential]$Credential,
    [string]$Server,

    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'

# --- Resolve server if not provided ---
if (-not $Server) {
    $Server = ($DomainDN -replace 'DC=','' -replace ',','.') -replace '\.$',''
}

# --- Build LDAP path ---
function Get-LdapPath {
    param([string]$DN)
    return "LDAP://$Server/$DN"
}

function Get-DirectoryEntry {
    param([string]$DN)
    $path = Get-LdapPath -DN $DN
    if ($Credential) {
        return [System.DirectoryServices.DirectoryEntry]::new($path, $Credential.UserName, $Credential.GetNetworkCredential().Password)
    }
    return [System.DirectoryServices.DirectoryEntry]::new($path)
}

# --- Container for synthetic objects ---
$containerName = 'CN=MaesterScaleTest'
$containerDN = "$containerName,$DomainDN"

# --- Cleanup ---
if ($Cleanup) {
    Write-Host "Cleaning up synthetic objects..." -ForegroundColor Yellow
    try {
        $root = Get-DirectoryEntry -DN $DomainDN
        $existing = $root.Children.Find($containerName)
        if ($existing) {
            if ($PSCmdlet.ShouldProcess($containerDN, 'Delete container and all children')) {
                $root.Children.Remove($existing)
                Write-Host "Removed $containerDN" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Container not found (nothing to clean)"
    }
    return
}

# --- Create top-level container ---
$root = Get-DirectoryEntry -DN $DomainDN
$container = $null

try {
    $container = $root.Children.Find($containerName)
    Write-Host "Using existing container: $containerDN"
} catch {
    if ($PSCmdlet.ShouldProcess($containerDN, 'Create container')) {
        $container = $root.Children.Add($containerName, 'container')
        $container.CommitChanges()
        Write-Host "Created container: $containerDN"
    }
}

# --- Permission patterns for ACE diversity ---
$acePatterns = @(
    @{ Rights = 'GenericAll'; Type = 'Allow'; Inherited = $false },
    @{ Rights = 'GenericRead'; Type = 'Allow'; Inherited = $true },
    @{ Rights = 'WriteProperty'; Type = 'Allow'; Inherited = $false },
    @{ Rights = 'Delete'; Type = 'Deny'; Inherited = $false },
    @{ Rights = 'CreateChild'; Type = 'Allow'; Inherited = $true },
    @{ Rights = 'ReadProperty'; Type = 'Deny'; Inherited = $false },
    @{ Rights = 'GenericWrite'; Type = 'Allow'; Inherited = $true },
    @{ Rights = 'ListChildren'; Type = 'Allow'; Inherited = $false }
)

# --- Helper: create ACE ---
function Add-Ace {
    param(
        [System.DirectoryServices.DirectoryEntry]$Target,
        [string]$Trustee,  # e.g. "DOMAIN\User" or SID string
        [string]$Rights,
        [string]$Type,
        [bool]$Inherited
    )
    $sd = $Target.ObjectSecurity
    $rule = [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
        ([System.Security.Principal.NTAccount]$Trustee),
        [System.DirectoryServices.ActiveDirectoryRights]::$Rights,
        [System.Security.AccessControl.AccessControlType]::$Type,
        [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All,
        [guid]::Empty
    )
    $sd.AddAccessRule($rule)
    $Target.ObjectSecurity = $sd
    $Target.CommitChanges()
}

# --- Helper: random trustee selection ---
function Get-RandomTrustee {
    param([string]$DomainNetbios)
    $trustees = @(
        'Authenticated Users',
        'Everyone',
        'Domain Users',
        'Domain Admins',
        'Enterprise Admins',
        'SYSTEM',
        "$DomainNetbios\maesterreader",
        'SELF'
    )
    return $trustees | Get-Random
}

# --- Resolve domain NETBIOS name ---
$domainNetbios = ($DomainDN -split ',')[0] -replace 'DC=',''

# --- Progress tracking ---
$totalObjects = $OuCount + ($OuCount * $GroupsPerOu) + ($OuCount * $GroupsPerOu * $UsersPerGroup)
$created = 0

Write-Host ""
Write-Host "Generating $totalObjects objects ($OuCount OUs × $GroupsPerOu groups × $UsersPerGroup users)..."
Write-Host ""

# --- Create OUs ---
$ouList = [System.Collections.Generic.List[object]]::new()
for ($ouIndex = 1; $ouIndex -le $OuCount; $ouIndex++) {
    $ouName = "OU=ScaleOU{0:D3}" -f $ouIndex
    $ouDN = "$ouName,$containerDN"

    try {
        $ou = $container.Children.Add($ouName, 'organizationalUnit')
        $ou.CommitChanges()
        $created++

        # Add diverse ACEs to OU
        1..3 | ForEach-Object {
            $pattern = $acePatterns | Get-Random
            Add-Ace -Target $ou -Trustee (Get-RandomTrustee -DomainNetbios $domainNetbios) `
                -Rights $pattern.Rights -Type $pattern.Type -Inherited $pattern.Inherited
        }

        $ouList.Add($ou)

        if ($ouIndex % 5 -eq 0 -or $ouIndex -eq $OuCount) {
            Write-Host "  [$created/$totalObjects] Created OU: $ouName with $($ou.ObjectSecurity.GetAccessRules($true,$true,[System.Security.Principal.NTAccount]).Count) ACEs"
        }
    } catch {
        Write-Warning "Failed to create OU $ouName : $_"
    }
}

# --- Create Groups per OU ---
$groupList = [System.Collections.Generic.List[object]]::new()
foreach ($ou in $ouList) {
    for ($gIndex = 1; $gIndex -le $GroupsPerOu; $gIndex++) {
        $groupName = "CN=ScaleGroup{0:D4}" -f ($groupList.Count + 1)
        try {
            $group = $ou.Children.Add($groupName, 'group')
            $group.Properties['sAMAccountName'].Value = "ScaleGroup{0:D4}" -f ($groupList.Count + 1)
            $group.Properties['groupType'].Value = -2147483646  # Global security group
            $group.CommitChanges()
            $created++

            # Add diverse ACEs to group
            1..2 | ForEach-Object {
                $pattern = $acePatterns | Get-Random
                Add-Ace -Target $group -Trustee (Get-RandomTrustee -DomainNetbios $domainNetbios) `
                    -Rights $pattern.Rights -Type $pattern.Type -Inherited $pattern.Inherited
            }

            $groupList.Add($group)

            if ($groupList.Count % 25 -eq 0 -or $groupList.Count -eq ($OuCount * $GroupsPerOu)) {
                Write-Host "  [$created/$totalObjects] Created group: $($group.Properties['sAMAccountName'].Value) with $($group.ObjectSecurity.GetAccessRules($true,$true,[System.Security.Principal.NTAccount]).Count) ACEs"
            }
        } catch {
            Write-Warning "Failed to create group $groupName : $_"
        }
    }
}

# --- Create Users per Group ---
$userList = [System.Collections.Generic.List[object]]::new()
foreach ($group in $groupList) {
    $ou = $group.Parent
    for ($uIndex = 1; $uIndex -le $UsersPerGroup; $uIndex++) {
        $userName = "CN=ScaleUser{0:D5}" -f ($userList.Count + 1)
        $samAccountName = "ScaleUser{0:D5}" -f ($userList.Count + 1)
        try {
            $user = $ou.Children.Add($userName, 'user')
            $user.Properties['sAMAccountName'].Value = $samAccountName
            $user.Properties['userPrincipalName'].Value = "$samAccountName@$Server"
            $user.Properties['displayName'].Value = "Scale User $samAccountName"
            $user.Properties['givenName'].Value = 'Scale'
            $user.Properties['sn'].Value = "User$userList.Count"
            $user.Properties['userAccountControl'].Value = 512  # Normal account
            $user.CommitChanges()
            $created++

            # Set password
            $user.Invoke('SetPassword', @('P@ssw0rd123!'))
            $user.Properties['pwdLastSet'].Value = 0
            $user.CommitChanges()

            # Add diverse ACEs to user
            1..2 | ForEach-Object {
                $pattern = $acePatterns | Get-Random
                Add-Ace -Target $user -Trustee (Get-RandomTrustee -DomainNetbios $domainNetbios) `
                    -Rights $pattern.Rights -Type $pattern.Type -Inherited $pattern.Inherited
            }

            # Add user to group
            $group.Properties['member'].Add($user.Properties['distinguishedName'].Value)
            $group.CommitChanges()

            $userList.Add($user)

            if ($userList.Count % 100 -eq 0 -or $userList.Count -eq ($groupList.Count * $UsersPerGroup)) {
                Write-Host "  [$created/$totalObjects] Created user: $samAccountName with $($user.ObjectSecurity.GetAccessRules($true,$true,[System.Security.Principal.NTAccount]).Count) ACEs"
            }
        } catch {
            Write-Warning "Failed to create user $userName : $_"
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Synthetic object generation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Total created: $created / $totalObjects"
Write-Host "  OUs:      $($ouList.Count)"
Write-Host "  Groups:   $($groupList.Count)"
Write-Host "  Users:    $($userList.Count)"
Write-Host "Container:  $containerDN"
Write-Host ""
Write-Host "To clean up:"
Write-Host "  ./New-MtLabSyntheticObjects.ps1 -DomainDN '$DomainDN' -Cleanup"

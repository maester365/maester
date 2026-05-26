function Test-MtXspmHybridUsersWithAssignedEntraIdRolesCompliance {
    <#
    .SYNOPSIS
    Tests if hybrid users have been assigned eligible or permanent to Entra ID roles.

    .DESCRIPTION
    This function checks if any hybrid users (synchronized from on-premises Active Directory) have been assigned eligible or permanent Entra ID roles, which can lead to privilege escalation by compromising the on-premises AD.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmHybridUsersWithAssignedEntraIdRolesCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo ..."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        return $null
    }

    $HighPrivilegedUsersByEntraRoles = $UnifiedIdentityInfo | Where-Object { $_.Type -eq "User" -and ($_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True) | Sort-Object Classification, AccountDisplayName}
    $HighPrivilegedHybridUsers = $HighPrivilegedUsersByEntraRoles | Where-Object { $_.SourceProvider -eq "ActiveDirectory" -or $_.SourceProvider -eq "Hybrid"}

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($HighPrivilegedHybridUsers)) {
    } else {

        $result = "| AccountName | Classification | Sensitive Directory Role | ChangeSource |`n"
        $result += "| --- | --- | --- | --- |`n"

        Write-Verbose "Found $($HighPrivilegedHybridUsers.Count) hybrid users with directory roles in total."

        foreach ($HighPrivilegedHybridUser in $HighPrivilegedHybridUsers) {
            $filteredDirectoryRoles = $HighPrivilegedHybridUser.AssignedEntraRoles | Where-Object { $_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True} | Select-Object RoleDefinitionName, Classification
            $UserSensitiveDirectoryRoles = $filteredDirectoryRoles | foreach-object { (Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $_.Classification) + " " + $_.RoleDefinitionName }
            $UserSensitiveDirectoryRolesResult = @()
            $UserSensitiveDirectoryRoles | ForEach-Object {
                $UserSensitiveDirectoryRolesResult += '`' + $_ + '`'
            }
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $HighPrivilegedHybridUser.Classification
            if ($HighPrivilegedHybridUser.Classification -eq "ControlPlane") {
                $Severity = "High"
            }

            $HybridUserLink = "[$($HighPrivilegedHybridUser.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($HighPrivilegedHybridUser.AccountObjectId))"
            $result += "| $($AdminTierLevelIcon) $($HybridUserLink) | $($HighPrivilegedHybridUser.Classification) | $($UserSensitiveDirectoryRolesResult) | $($HighPrivilegedHybridUser.SourceProvider) |`n"
        }
    }

    $result = [string]::IsNullOrEmpty($HighPrivilegedHybridUsers)
    return $result

}

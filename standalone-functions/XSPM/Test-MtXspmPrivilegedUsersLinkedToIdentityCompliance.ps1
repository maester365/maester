function Test-MtXspmPrivilegedUsersLinkedToIdentityCompliance {
    <#
    .SYNOPSIS
    Tests if privileged users with assigned high privileged Entra ID roles are linked to an identity.

    .DESCRIPTION
    This function checks if any enabled privileged users with assigned high privileged Entra ID roles are linked to an identity in Microsoft Defender XDR.
    Emergency access accounts defined in the Maester config under 'EmergencyAccessAccounts' are excluded from this test.
    Entra ID role members should be a separate account from the day-to-day user account to reduce the attack surface but also linked in Defender XDR for visibility and option to apply containment to all associated accounts in case of a identity compromise.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmPrivilegedUsersLinkedToIdentityCompliance
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

    $UnlinkedPrivilegedUsers = $UnifiedIdentityInfo `
        | Where-Object {
                $_.Type -eq "User" `
                -and $_.AccountStatus -eq "Enabled" `
                -and ($_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True) `
                -and ($_.AssignedEntraRoles.RoleDefinitionName -notcontains "Directory Synchronization Accounts") `
                -and ($null -eq $_.AssociatedPrimaryAccount) `
            } `
        | Sort-Object Classification, AccountDisplayName

    $EmergencyAccessAccounts = Get-MtMaesterConfigGlobalSetting -SettingName 'EmergencyAccessAccounts'
    if ($EmergencyAccessAccounts -and $EmergencyAccessAccounts.Count -gt 0) {
        Write-Verbose "Excluding Emergency Access Accounts from the test results ..."
        $UnlinkedPrivilegedUsers = $UnlinkedPrivilegedUsers | Where-Object { $_.AccountUpn -notin $EmergencyAccessAccounts.UserPrincipalName }
    }

    $Severity = "Low"

    if ([string]::IsNullOrEmpty($UnlinkedPrivilegedUsers)) {
    } else {

        $result = "| AccountName | Classification | Sensitive Directory Role | CriticalAssetDetails |`n"
        $result += "| --- | --- | --- | --- |`n"

        Write-Verbose "Found $($UnlinkedPrivilegedUsers.Count) high privileged users not linked to an identity."

        foreach ($UnlinkedPrivilegedUser in $UnlinkedPrivilegedUsers) {
            $filteredDirectoryRoles = $UnlinkedPrivilegedUser.AssignedEntraRoles | Where-Object { $_.Classification -eq "ControlPlane" -or $_.RoleIsPrivileged -eq $True} | Select-Object RoleDefinitionName, Classification
            $UserSensitiveDirectoryRoles = $filteredDirectoryRoles | foreach-object { (Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $_.Classification) + " " + $_.RoleDefinitionName }
            $UserSensitiveDirectoryRolesResult = @()
            $UserSensitiveDirectoryRoles | ForEach-Object {
                $UserSensitiveDirectoryRolesResult += '`' + $_ + '`'
            }
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $UnlinkedPrivilegedUser.Classification
            if ($UnlinkedPrivilegedUser.Classification -eq "ControlPlane") {
                $Severity = "High"
            }

            $PrivilegedUserLink = "[$($UnlinkedPrivilegedUser.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($UnlinkedPrivilegedUser.AccountObjectId))"
            $result += "| $($AdminTierLevelIcon) $($PrivilegedUserLink) | $($UnlinkedPrivilegedUser.Classification) | $($UserSensitiveDirectoryRolesResult) | $($UnlinkedPrivilegedUser.CriticalAssetDetails) |`n"
        }
    }

    $result = [string]::IsNullOrEmpty($UnlinkedPrivilegedUsers)
    return $result

}

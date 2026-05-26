function Test-MtXspmEnabledPrivilegedUsersLinkedToDisabledIdentityCompliance {
    <#
    .SYNOPSIS
    Tests if enabled privileged users with assigned high privileged Entra ID roles or criticality level (<= 1) are linked to a disabled identity in Microsoft Defender XDR.

    .DESCRIPTION
    This function checks if any enabled privileged users with assigned high privileged Entra ID roles or criticality level (<= 1) are linked to a disabled identity in Microsoft Defender XDR. Having enabled privileged users linked to disabled identities can pose a security risk, as it may indicate orphaned privileged accounts that could be exploited by attackers.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmEnabledPrivilegedUsersLinkedToDisabledIdentityCompliance
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

    $EnabledPrivUsersToDisabledAccounts = $UnifiedIdentityInfo `
        | Where-Object {
                $_.Type -eq "User" `
                -and $_.AccountStatus -eq "Enabled" `
                -and (($_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane") -or $_.CriticalityLevel -le 1) `
                -and $_.AssociatedPrimaryAccount.AccountStatus -eq "Disabled" `
            } `
        | Sort-Object Classification, AccountDisplayName

    $Severity = "Medium"

    if ([string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)) {
    } else {

        $result = "| AccountName | Classification | CriticalityLevel | Linked Identity |`n"
        $result += "| --- | --- | --- | --- |`n"

        Write-Verbose "Found $($EnabledPrivUsersToDisabledAccounts.Count) enabled and privileged users linked to disabled identities in total."

        foreach ($EnabledPrivUsersToDisabledAccount in $EnabledPrivUsersToDisabledAccounts) {
            $filteredDirectoryRoles = $EnabledPrivUsersToDisabledAccount.AssignedEntraRoles | Where-Object { $_.Classification -eq "ControlPlane" -or $_.RoleIsPrivileged -eq $True} | Select-Object RoleDefinitionName, Classification
            $UserSensitiveDirectoryRoles = $filteredDirectoryRoles | foreach-object { (Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $_.Classification) + " " + $_.RoleDefinitionName }
            $UserSensitiveDirectoryRolesResult = @()
            $UserSensitiveDirectoryRoles | ForEach-Object {
                $UserSensitiveDirectoryRolesResult += '`' + $_ + '`'
            }
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $EnabledPrivUsersToDisabledAccount.Classification
            if ($EnabledPrivUsersToDisabledAccount.Classification -eq "ControlPlane") {
                $Severity = "High"
            }

            $PrivilegedUserLink = "[$($EnabledPrivUsersToDisabledAccount.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($EnabledPrivUsersToDisabledAccount.AccountObjectId))"
            $PrimaryIdentityLink = "[$($EnabledPrivUsersToDisabledAccount.AssociatedPrimaryAccount.AccountUpn)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($EnabledPrivUsersToDisabledAccount.AssociatedPrimaryAccount.AccountObjectId))"
            $result += "| $($AdminTierLevelIcon) $($PrivilegedUserLink) | $($EnabledPrivUsersToDisabledAccount.Classification) | $($EnabledPrivUsersToDisabledAccount.CriticalityLevel) | $($PrimaryIdentityLink) |`n"
        }
    }

    $result = [string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)
    return $result

}

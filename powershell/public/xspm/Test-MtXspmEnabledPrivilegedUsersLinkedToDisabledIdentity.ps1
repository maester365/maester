<#
.SYNOPSIS
    Tests if privileged users with assigned high privileged Entra ID roles are linked to an identity.

.DESCRIPTION
    This function checks if any enabled privileged users with assigned high privileged Entra ID roles are linked to an identity in Microsoft Defender XDR.
    Emergency access accounts defined in the Maester config under 'EmergencyAccessAccounts' are excluded from this test.
    Entra ID role members should be a separate account from the day-to-day user account to reduce the attack surface but also linked in Defender XDR for visibility and option to apply containment to all associated accounts in case of a identity compromise.

.OUTPUTS
    [bool] - Returns $true if all sensitive privileged users are linked to an identity, $false if any are found not linked, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmPrivilegedUsersLinkedToIdentity

.LINK
    https://maester.dev/docs/commands/Test-MtXspmPrivilegedUsersLinkedToIdentity
#>

function Test-MtXspmEnabledPrivilegedUsersLinkedToDisabledIdentity {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users and roles.')]
    [OutputType([bool])]
    param()

    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables. Check https://maester.dev/docs/tests/MT.1081/#Prerequisites for more information.'
            return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo ..."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    $EnabledPrivUsersToDisabledAccounts = $UnifiedIdentityInfo `
        | Where-Object {
                $_.Type -eq "User" `
                -and $_.AccountStatus -eq "Enabled" `
                -and ($_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True) `
                -and $_.AssociatedPrimaryAccount.AccountStatus -eq "Disabled" `
            } `
        | Sort-Object Classification, AccountDisplayName

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)) {
        $testResultMarkdown = "Well done. No enabled privileged users linked to disabled identity."
    } else {
        $testResultMarkdown = "At least one enabled and privileged user is linked to a disabled identity.`n`n%TestResult%"

        $result = "| AccountName | Classification | Sensitive Directory Role | Linked Identity |`n"
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
            $result += "| $($AdminTierLevelIcon) $($PrivilegedUserLink) | $($EnabledPrivUsersToDisabledAccount.Classification) | $($UserSensitiveDirectoryRolesResult) | $($PrimaryIdentityLink) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity

    $result = [string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)
    return $result
}

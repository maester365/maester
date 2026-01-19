<#
.SYNOPSIS
    Tests if enabled privileged users with assigned high privileged Entra ID roles or criticality level (<= 1) are linked to a disabled identity in Microsoft Defender XDR.

.DESCRIPTION
    This function checks if any enabled privileged users with assigned high privileged Entra ID roles or criticality level (<= 1) are linked to a disabled identity in Microsoft Defender XDR. Having enabled privileged users linked to disabled identities can pose a security risk, as it may indicate orphaned privileged accounts that could be exploited by attackers.

.OUTPUTS
    [bool] - Returns $true if no enabled privileged users are linked to disabled identities, otherwise returns $false.

.EXAMPLE
    Test-MtXspmEnabledPrivilegedUsersLinkedToDisabledIdentity

.LINK
    https://maester.dev/docs/commands/Test-MtXspmEnabledPrivilegedUsersLinkedToDisabledIdentity
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
                -and (($_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane") -or $_.CriticalityLevel -le 1) `
                -and $_.AssociatedPrimaryAccount.AccountStatus -eq "Disabled" `
            } `
        | Sort-Object Classification, AccountDisplayName

    $Severity = "Medium"

    if ([string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)) {
        $testResultMarkdown = "Well done. No enabled privileged or critical users linked to disabled identity."
    } else {
        $testResultMarkdown = "At least one enabled critical or privileged user is linked to a disabled identity.`n`n%TestResult%"

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
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity

    $result = [string]::IsNullOrEmpty($EnabledPrivUsersToDisabledAccounts)
    return $result
}

function Test-MtCaExclusionForDirectorySyncAccount {
    <#
    .Synopsis
    Checks if all Conditional Access policies scoped to all cloud apps and all users exclude the directory synchronization accounts

    .Description
    The directory synchronization accounts are used to synchronize the on-premises directory with Entra ID.
    These accounts should be excluded from all Conditional Access policies scoped to all cloud apps and all users.
    Entra ID connect does not support multifactor authentication.
    Restrict access with these accounts to trusted networks.

    .Example
    Test-MtCaExclusionForDirectorySyncAccount

    .LINK
    https://maester.dev/docs/commands/Test-MtCaExclusionForDirectorySyncAccount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $testDescription = 'It is recommended to exclude directory/OnPremises synchronization accounts from all Conditional Access policies scoped to all cloud apps.'
    $testResult = "The following Conditional Access policies are scoped to all users but don't exclude the directory/OnPremises synchronization accounts:`n`n"

    try {
        $DirectorySynchronizationAccountsRole = Get-MtRoleInfo -RoleName 'DirectorySynchronizationAccounts'
        $OnPremisesDirectorySyncAccountRole = Get-MtRoleInfo -RoleName 'OnPremisesDirectorySyncAccount'

        $Members = @()
        $DirectorySynchronizationAccountsRoleId = $null
        $OnPremisesDirectorySyncAccountRoleId = $null
        # Guard: Get-MtRoleInfo returns $null when $script:MtRoles is uninitialised (module reload issue).
        # Skip the Get-MtRoleMember call in that case to avoid a mandatory-parameter binding error.
        if ($null -ne $DirectorySynchronizationAccountsRole) {
            $DirectorySynchronizationAccountsRoleId = $DirectorySynchronizationAccountsRole.Id
            $Members += Get-MtRoleMember -RoleId $DirectorySynchronizationAccountsRoleId
        }
        if ($null -ne $OnPremisesDirectorySyncAccountRole) {
            $OnPremisesDirectorySyncAccountRoleId = $OnPremisesDirectorySyncAccountRole.Id
            $Members += Get-MtRoleMember -RoleId $OnPremisesDirectorySyncAccountRoleId
        }
        $Members = @($Members | Where-Object { $null -ne $_ })

        if ( $Members.Count -eq 0 ) {
            Add-MtTestResultDetail -Description $testDescription -Result 'This tenant does not have directory synchronization accounts and therefore this test is not applicable.'
            return $true
        }

        # Classify members: user accounts (subject to Conditional Access policies) vs. service principals (not subject to CA).
        # As of Microsoft Entra Connect v2.5.76.0, directory sync supports Application-Based Authentication
        # (ABA), where sync is performed by a registered service principal rather than a dedicated user
        # account. Service principals are not subject to Conditional Access policies and do not need to be
        # excluded from them.
        $userSyncMembers = @($Members | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.servicePrincipal' })
        $spSyncMembers   = @($Members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.servicePrincipal' })

        if ( $userSyncMembers.Count -eq 0 -and $spSyncMembers.Count -gt 0 ) {
            $spNames = ( $spSyncMembers | Where-Object { $_.displayName } | ForEach-Object { $_.displayName } ) -join ', '
            if ( -not $spNames ) { $spNames = 'unknown' }
            Add-MtTestResultDetail -Description $testDescription -Result "This tenant uses Application-Based Authentication (ABA) for directory synchronization. As of Microsoft Entra Connect v2.5.76.0, sync can be performed by a registered service principal ($spNames) rather than a dedicated user account. Service principals are not subject to Conditional Access policies; no CA exclusions are required."
            return $true
        }

        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

        $result = $true
        foreach ($policy in ( $policies | Sort-Object -Property displayName ) ) {
            if ( $policy.conditions.applications.includeApplications -ne 'All' ) {
                # Skip this policy, because it does not apply to all applications
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) because it's not scoped to all apps - $CurrentResult"
                continue
            }

            if ( [string]::IsNullOrWhiteSpace($policy.conditions.users.includeUsers) -and `
                    [string]::IsNullOrWhiteSpace($policy.conditions.users.includeGroups) -and `
                    [string]::IsNullOrWhiteSpace($policy.conditions.users.includeRoles) -and `
                ( -not [string]::IsNullOrWhiteSpace($policy.conditions.users.includeGuestsOrExternalUsers) ) ) {
                # Skip this policy, because it does not apply to any internal users, but only guests
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) because no internal users is scoped - $CurrentResult"
                continue
            }

            if ( $policy.grantControls.builtInControls -contains 'block' `
                    -and 'exchangeActiveSync' -in $policy.conditions.clientAppTypes `
                    -and 'other' -in $policy.conditions.clientAppTypes) {
                # Skip this policy, because it just blocks legacy authentication
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) legacy auth is not used for sync - $CurrentResult"
                continue
            }

            $PolicyIncludesAnyMember = $false
            $PolicyIncludesRole = $false
            # Use the pre-computed $userSyncMembers list (service principals excluded above).
            $memberIds = @($userSyncMembers | ForEach-Object { $_.id })

            foreach ($memberId in $memberIds) {
                if ( $memberId -in $policy.conditions.users.includeUsers ) {
                    $PolicyIncludesAnyMember = $true
                    break
                }
            }

            if ( $DirectorySynchronizationAccountsRoleId -in $policy.conditions.users.includeRoles -or $OnPremisesDirectorySyncAccountRoleId -in $policy.conditions.users.includeRoles ) {
                $PolicyIncludesRole = $true
            }

            if ( $PolicyIncludesAnyMember -or $PolicyIncludesRole ) {
                # Skip this policy, because directory synchronization accounts are specifically included and therefore must not be excluded
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) - $CurrentResult"
                continue
            } elseif ( $memberIds.Count -eq 0 ) {
                # All members are service principals; they are not subject to Conditional Access policies and therefore this policy can be skipped
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) — only service principal members - $CurrentResult"
                continue
            } else {
                # Check if excluded by role
                $excludedByRole = $DirectorySynchronizationAccountsRoleId -in $policy.conditions.users.excludeRoles -or $OnPremisesDirectorySyncAccountRoleId -in $policy.conditions.users.excludeRoles

                # Check if all user members are individually excluded
                $excludedByMember = $memberIds.Count -gt 0 -and @($memberIds | Where-Object { $_ -notin $policy.conditions.users.excludeUsers }).Count -eq 0

                if ( $excludedByRole -or $excludedByMember ) {
                    # Directory synchronization accounts are excluded
                    $CurrentResult = $true
                } else {
                    # Directory synchronization accounts are not excluded
                    $CurrentResult = $false
                    $result = $false
                    $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
                }
            }

            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
            $testResult = 'All Conditional Access policies scoped to all cloud apps exclude the directory synchronization accounts.'
        }

        Add-MtTestResultDetail -Description $testDescription -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

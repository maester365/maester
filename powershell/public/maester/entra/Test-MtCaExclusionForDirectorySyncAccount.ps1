function Test-MtCaExclusionForDirectorySyncAccount {
    <#
    .Synopsis
    Checks whether Conditional Access policies exclude user-based Microsoft Entra Connect synchronization identities.

    .Description
    Microsoft Entra Connect uses a connector identity to synchronize an on-premises directory with Microsoft Entra ID.
    Legacy installations can use a user-based directory synchronization account. These accounts should be excluded from
    Conditional Access policies scoped to all cloud apps and all users, and their access should be restricted to trusted
    networks.

    New installations of Microsoft Entra Connect 2.5.76.0 or later use application-based authentication by default, with a
    service principal and certificate instead of a user account and password. Existing installations do not switch to
    application-based authentication automatically.

    This test evaluates user principals assigned to the directory synchronization roles. It passes automatically when no
    user principals remain, because Conditional Access user exclusions do not apply to service principals; the test does not
    need to be muted. To verify the authentication method currently used, run Get-ADSyncEntraConnectorCredential on every
    Microsoft Entra Connect server and confirm that ConnectorIdentityType is Application. After verifying the migration,
    remove the legacy directory synchronization account or remove its directory synchronization role assignment.

    .Example
    Test-MtCaExclusionForDirectorySyncAccount

    .LINK
    https://maester.dev/docs/commands/Test-MtCaExclusionForDirectorySyncAccount

    .LINK
    https://learn.microsoft.com/entra/identity/hybrid/connect/authenticate-application-id
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

        # Classify role members by whether Conditional Access user targeting applies. Role membership establishes
        # whether user principals need CA handling, but it does not prove which credential an active Connect server uses.
        $userSyncMembers = @($Members | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.servicePrincipal' })
        $spSyncMembers   = @($Members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.servicePrincipal' })

        if ( $userSyncMembers.Count -eq 0 -and $spSyncMembers.Count -gt 0 ) {
            $spNames = ( $spSyncMembers | Where-Object { $_.displayName } | ForEach-Object { $_.displayName } ) -join ', '
            if ( -not $spNames ) { $spNames = 'unknown' }
            Add-MtTestResultDetail -Description $testDescription -Result "Only service principals are assigned to the directory synchronization roles ($spNames). Conditional Access user exclusions do not apply to service principals, so this test is not applicable. Role membership alone does not confirm that an active Microsoft Entra Connect server uses application-based authentication; verify each server with Get-ADSyncEntraConnectorCredential."
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
                # All members are service principals; they are not subject to CA policies and therefore this policy can be skipped
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

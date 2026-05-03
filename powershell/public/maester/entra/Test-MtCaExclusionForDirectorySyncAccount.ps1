function Test-MtCaExclusionForDirectorySyncAccount {
    <#
    .Synopsis
    Checks if all conditional access policies scoped to all cloud apps and all users exclude the directory synchronization accounts

    .Description
    The directory synchronization accounts are used to synchronize the on-premises directory with Entra ID.
    These accounts should be excluded from all conditional access policies scoped to all cloud apps and all users.
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

    $testDescription = 'It is recommended to exclude directory/OnPremises synchronization accounts from all conditional access policies scoped to all cloud apps.'
    $testResult = "The following conditional access policies are scoped to all users but don't exclude the directory/OnPremises synchronization accounts:`n`n"

    try {
        # Role template IDs are stable Microsoft-defined GUIDs; use them as fallback
        # when Get-MtRoleInfo cannot resolve via the module role definitions cache.
        # Variables kept as strings so they work correctly in -in comparisons against
        # CA policy conditions (includeRoles/excludeRoles contain GUID strings).
        $dirSyncInfo = Get-MtRoleInfo -RoleName 'DirectorySynchronizationAccounts'
        $DirectorySynchronizationAccountsRole = if ($null -ne $dirSyncInfo) { $dirSyncInfo.ToString() } else { 'd29b2b05-8046-44ba-8758-1e26182fcf32' }

        $onPremInfo = Get-MtRoleInfo -RoleName 'OnPremisesDirectorySyncAccount'
        $OnPremisesDirectorySyncAccountRole = if ($null -ne $onPremInfo) { $onPremInfo.ToString() } else { 'a92aed5d-d78a-4d16-b381-09adb37eb3b0' }

        $Members = @()
        $Members += Get-MtRoleMember -RoleId ([guid]$DirectorySynchronizationAccountsRole)
        $Members += Get-MtRoleMember -RoleId ([guid]$OnPremisesDirectorySyncAccountRole)
        $Members = @($Members | Where-Object { $null -ne $_ })

        if ( $Members.Count -eq 0 ) {
            Add-MtTestResultDetail -Description $testDescription -Result 'This tenant does not have directory synchronization accounts and therefore this test is not applicable.'
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
            # Excluding service principals, because they cannot be excluded from policies and therefore do not have to be included in the policies to bypass them.
            $memberIds = @($Members | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.servicePrincipal' } | ForEach-Object { $_.id })

            foreach ($memberId in $memberIds) {
                if ( $memberId -in $policy.conditions.users.includeUsers ) {
                    $PolicyIncludesAnyMember = $true
                    break
                }
            }

            if ( $DirectorySynchronizationAccountsRole -in $policy.conditions.users.includeRoles -or $OnPremisesDirectorySyncAccountRole -in $policy.conditions.users.includeRoles ) {
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
                $excludedByRole = $DirectorySynchronizationAccountsRole -in $policy.conditions.users.excludeRoles -or $OnPremisesDirectorySyncAccountRole -in $policy.conditions.users.excludeRoles

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
            $testResult = 'All conditional access policies scoped to all cloud apps exclude the directory synchronization accounts.'
        }

        Add-MtTestResultDetail -Description $testDescription -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

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

    try {
        $DirectorySynchronizationAccountsRole = Get-MtRoleInfo -RoleName "DirectorySynchronizationAccounts"
        $OnPremisesDirectorySyncAccountRole = Get-MtRoleInfo -RoleName "OnPremisesDirectorySyncAccount"

        try {
            $Members = Get-MtRoleMember -RoleId $DirectorySynchronizationAccountsRole
            $Members += Get-MtRoleMember -RoleId $OnPremisesDirectorySyncAccountRole
            if ( $null -eq $Members ) {
                # Assumes if no accounts has any of those permissions that there is no directory/OnPremises synchronization accounts
                Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Directory synchronization accounts not found, but directory synchronization is configured. This might be caused by missing permissions to read the directory synchronization accounts.'
                throw 'Directory synchronization and/or on-premises directory synchronization accounts not found'
            }
        } catch {
            # Directory synchronization account role not found, this tenant does not have directory/OnPremises synchronization accounts
            Add-MtTestResultDetail -Description $testDescription -Result 'This tenant does not have directory/OnPremises synchronization accounts and therefor this test is not applicable.'
            return $true
        }

        $testDescription = 'It is recommended to exclude directory/OnPremises synchronization accounts from all conditional access policies scoped to all cloud apps.'
        $testResult = "The following conditional access policies are scoped to all users but don't exclude the directory/OnPremises synchronization accounts:`n`n"

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

            $PolicyIncludesMember = $false
            $PolicyIncludesRole = $false
            $memberIds = @($Members | ForEach-Object { $_.id })

            foreach ($memberId in $memberIds) {
                if ( $memberId -in $policy.conditions.users.includeUsers ) {
                    $PolicyIncludesMember = $true
                    break
                }
            }

            if ( $DirectorySynchronizationAccountsRole -in $policy.conditions.users.includeRoles -or $OnPremisesDirectorySyncAccountRole -in $policy.conditions.users.includeRoles ) {
                $PolicyIncludesRole = $true
            }

            if ( $PolicyIncludesMember -or $PolicyIncludesRole ) {
                # Skip this policy, because directory synchronization accounts are specifically included and therefor must not be excluded
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) - $CurrentResult"
            } else {
                # Check if excluded by role
                $excludedByRole = $DirectorySynchronizationAccountsRole -in $policy.conditions.users.excludeRoles -or $OnPremisesDirectorySyncAccountRole -in $policy.conditions.users.excludeRoles

                # Check if all members (users and service principals) are individually excluded
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

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
function Test-MtCaExclusionForDirectorySyncAccount {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'PolicyIncludesAllUsers is used in the condition.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $testDescription = 'It is recommended to exclude directory synchronization accounts from all conditional access policies scoped to all cloud apps.'
        $testResult = "The following conditional access policies are scoped to all users but don't exclude the directory synchronization accounts:`n`n"

        $DirectorySynchronizationAccountRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        try {
            $DirectorySynchronizationAccountRoleId = Invoke-MtGraphRequest -RelativeUri "directoryRoles(roleTemplateId='$DirectorySynchronizationAccountRoleTemplateId')" -Select id | Select-Object -ExpandProperty id
            $DirectorySynchronizationAccounts = Invoke-MtGraphRequest -RelativeUri "directoryRoles/$DirectorySynchronizationAccountRoleId/members" -Select id | Get-ObjectProperty -Property id
            if ( $null -eq $DirectorySynchronizationAccounts ) {
                throw 'Directory synchronization accounts not found'
            }
        } catch {
            # Directory synchronization account role not found, this tenant does not have directory synchronization accounts
            Add-MtTestResultDetail -Description $testDescription -Result 'This tenant does not have directory synchronization accounts and therefor this test is not applicable.'
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

            $PolicyIncludesAllUsers = $false
            $PolicyIncludesRole = $false
            $DirectorySynchronizationAccounts | ForEach-Object {
                if ( $_ -in $policy.conditions.users.includeUsers  ) {
                    $PolicyIncludesAllUsers = $true
                }
            }

            if ( $DirectorySynchronizationAccountRoleTemplateId -in $policy.conditions.users.includeRoles ) {
                $PolicyIncludesRole = $true
            }

            if ( $PolicyIncludesAllUsers -or $PolicyIncludesRole ) {
                # Skip this policy, because all directory synchronization accounts are included and therefor must not be excluded
                $CurrentResult = $true
                Write-Verbose "Skipping $($policy.displayName) - $CurrentResult"
            } else {
                if ( $DirectorySynchronizationAccountRoleTemplateId -in $policy.conditions.users.excludeRoles ) {
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

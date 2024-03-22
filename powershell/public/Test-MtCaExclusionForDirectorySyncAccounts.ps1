<#
 .Synopsis
  Checks if all conditional access policies scoped to all cloud apps exclude the directory synchronization accounts

 .Description
    The directory synchronization accounts are used to synchronize the on-premises directory with Entra ID.
    These accounts should be excluded from all conditional access policies scoped to all cloud apps.
    Entra ID connect does not support multifactor authentication.
    Restrict access with these accounts to trusted networks.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-admin-mfa

 .Example
  Test-MtCaExclusionForDirectorySyncAccounts
#>

Function Test-MtCaExclusionForDirectorySyncAccounts {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $DirectorySynchronizationAccountRoleTemplateId = "d29b2b05-8046-44ba-8758-1e26182fcf32"
    $DirectorySynchronizationAccountRoleId = Invoke-MtGraphRequest -RelativeUri "directoryRoles(roleTemplateId='$DirectorySynchronizationAccountRoleTemplateId')" -Select id | Select-Object -ExpandProperty id
    $DirectorySynchronizationAccounts = Invoke-MtGraphRequest -RelativeUri "directoryRoles/$DirectorySynchronizationAccountRoleId/members" -Select id | Select-Object -ExpandProperty id

    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }

    $result = $true
    foreach ($policy in ( $policies | Sort-Object -Property displayName ) ) {
        if ( $policy.conditions.applications.includeApplications -ne "All" ) {
            # Skip this policy, because it does not apply to all applications
            $currentresult = $true
            Write-Verbose "Skipping $($policy.displayName) - $currentresult"
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
            $currentresult = $true
            Write-Verbose "Skipping $($policy.displayName) - $currentresult"
        } else {
            if ( $DirectorySynchronizationAccountRoleTemplateId -in $policy.conditions.users.excludeRoles ) {
                # Directory synchronization accounts are excluded
                $currentresult = $true
            } else {
                # Directory synchronization accounts are not excluded
                $currentresult = $false
                $result = $false
            }
        }

        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    return $result
}
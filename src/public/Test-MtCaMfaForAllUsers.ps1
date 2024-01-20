<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all users

 .Description
    MFA for all users conditional access policy can be used to require MFA for all users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa

 .Example
  Test-MtCaMfaForAllUsers
#>

Function Test-MtCaMfaForAllUsers {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $result = $false
    foreach ($policy in $policies) {
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' ) -and $policy.conditions.users.includeUsers -eq "All" -and $policy.conditions.applications.includeApplications -eq "All" ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }
    Set-StrictMode -Version Latest

    return $result
}
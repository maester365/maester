<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy that blocks legacy authentication.

 .Description
    Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
    conditional access policy that blocks legacy authentication.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy

 .Example
  Test-MtCaBlockLegacyOtherAuthentication
#>

Function Test-MtCaBlockLegacyOtherAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $result = $false
    foreach ($policy in $policies) {
        if ( $policy.grantcontrols.builtincontrols -contains 'block' -and "other" -in $policy.conditions.clientAppTypes -and $policy.conditions.applications.includeApplications -eq "All" -and $policy.conditions.users.includeUsers -eq "All" ) {
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
<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy securing security info registration.

 .Description
    Security info registration conditional access policy can secure the registration of security info for users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-registration

 .Example
  Test-MtCaSecureSecurityInfoRegistration
#>

Function Test-MtCaSecureSecurityInfoRegistration {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $result = $false
    foreach ($policy in $policies) {
        if ( $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.clientAppTypes -eq "all" `
                -and $policy.conditions.applications.includeUserActions -eq "urn:user:registersecurityinfo" `
                -and $policy.conditions.users.excludeRoles -eq "62e90394-69f5-4237-9190-012177145e10" `
                -and $policy.conditions.locations.excludeLocations -eq "AllTrusted" `
        ) {
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
<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy securing security info registration.

 .Description
    Security info registration conditional access policy can secure the registration of security info for users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-registration

 .Example
  Test-MtCaSecureSecurityInfoRegistration

.LINK
    https://maester.dev/docs/commands/Test-MtCaSecureSecurityInfoRegistration
#>
function Test-MtCaSecureSecurityInfoRegistration {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }
    $policiesResult = New-Object System.Collections.ArrayList

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
            $policiesResult.Add($policy) | Out-Null
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    if ( $result ) {
        $testResult = "The following conditional access policies secure security info registration.`n`n%TestResult%"
    } else {
        $testResult = "No conditional access policy securing security info registration."
    }
    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}
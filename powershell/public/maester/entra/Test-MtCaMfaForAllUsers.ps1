<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all users

 .Description
    MFA for all users conditional access policy can be used to require MFA for all users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa

 .Example
  Test-MtCaMfaForAllUsers

.LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForAllUsers
#>
function Test-MtCaMfaForAllUsers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'AllUsers is a well known term for conditional access policies.')]
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
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' `
                    -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' `
                    -or $policy.grantcontrols.customAuthenticationFactors -ne "" ) `
                -and $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.applications.includeApplications -eq "All" `
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
        $testResult = "The following conditional access policies require multi-factor authentication for all users:`n`n%TestResult%"
    } else {
        $testResult = "No conditional access policy requires multi-factor authentication for all users."
    }

    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}

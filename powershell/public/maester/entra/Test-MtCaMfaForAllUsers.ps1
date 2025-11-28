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

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa' -or
                    $policy.grantControls.customAuthenticationFactors -ne ''
                ) -and
                $policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.applications.includeApplications -eq 'All'
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
            $testResult = "The following conditional access policies require multi-factor authentication for all users:`n`n%TestResult%"
        } else {
            $testResult = 'No conditional access policy requires multi-factor authentication for all users.'
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -Error $_ -GraphObjectType ConditionalAccess
        return $false
    }
}

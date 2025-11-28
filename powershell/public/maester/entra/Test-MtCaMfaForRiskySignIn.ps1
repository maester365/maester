<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication for risky sign-ins.

 .Description
    MFA for risky sign-ins conditional access policy can be used to require MFA for all users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk

 .Example
  Test-MtCaMfaForRiskySignIn

.LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForRiskySignIn
#>
function Test-MtCaMfaForRiskySignIn {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
                ) -and
                $policy.conditions.users.includeUsers -eq "All" -and
                $policy.conditions.applications.includeApplications -eq "All" -and
                "high" -in $policy.conditions.signInRiskLevels -and
                "medium" -in $policy.conditions.signInRiskLevels
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
            $testResult = "The following conditional access policies require multi-factor authentication for risky sign-ins`n`n%TestResult%"
        } else {
            $testResult = "No conditional access policy requires multi-factor authentication for risky sign-ins."
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

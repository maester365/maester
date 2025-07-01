<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring password change for high user risk.

 .Description
    Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user

 .Example
  Test-MtCaRequirePasswordChangeForHighUserRisk

.LINK
    https://maester.dev/docs/commands/Test-MtCaRequirePasswordChangeForHighUserRisk
#>
function Test-MtCaRequirePasswordChangeForHighUserRisk {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -ne 'P2' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        # Only check policies that have password change as a grant control
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -contains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                $policy.grantControls.builtInControls -contains 'passwordChange' -and
                $policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.applications.includeApplications -eq 'All' -and
                'high' -in $policy.conditions.userRiskLevels
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
            $testResult = "The following conditional access policies require password change for risky users`n`n%TestResult%"
        } else {
            $testResult = 'No conditional access policy requires a password change for risky users.'
        }
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -Error $_ -GraphObjectType ConditionalAccess
        return $false
    }
}

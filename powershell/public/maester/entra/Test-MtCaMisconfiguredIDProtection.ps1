<#
 .Synopsis
Checks for common misconfigurations in Conditional Access - both user risk and sign-in risk are configured in one policy.

 .Description
Conditional Access policies access controls are enforced only if ALL conditions are met. Therefore, sign-in risk and user risk should be configured separately.

  Learn more:
  https://learn.microsoft.com/en-us/entra/id-protection/howto-identity-protection-configure-risk-policies

 .Example
  Test-MtCaMisconfiguredIDProtection

  .LINK
  https://maester.dev/docs/commands/Test-MtCaMisconfiguredIDProtection
#>

function Test-MtCaMisconfiguredIDProtection {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -ne 'P2' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        $hasRiskCAPolicy = $false # flag to check if there is any policy with risk controls, we skip the test if there is none

        foreach ($policy in $policies) {
            if ($policy.conditions.userRiskLevels -or $policy.conditions.signInRiskLevels) {
                $hasRiskCAPolicy = $true
            }
            if ($policy.conditions.userRiskLevels -and $policy.conditions.signInRiskLevels) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( -not $hasRiskCAPolicy ) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'There are no Conditional Access policies with risk controls configured.'
            return $null
        }

        if ( $result ) {
            $testResult = "The following conditional access policies have both sign-in risk and user risk controls configured:`n`n%TestResult%"
        } else {
            $testResult = 'Well done! No conditional access policies detected where sign-in risk and user risk are combined.'
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
        return $result
    } catch {
        Add-MtTestResultDetail -Error $_ -GraphObjectType ConditionalAccess
        return $false
    }
}

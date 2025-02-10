<#
 .Synopsis
Checks for common misconfigurations in Conditional Access: both user risk and sign-in risk are configured in one policy.

 .Description
Conditional Access policies' access controls are enforced only if ALL conditions are met. Therefore, sign-in risk and user risk should be configured separately.

  Learn more:
  https://learn.microsoft.com/en-us/entra/id-protection/howto-identity-protection-configure-risk-policies 

 .Example
  Test-MtCaMisconfiguredIDProtection
#>

Function Test-MtCaMisconfiguredIDProtection {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList

    $result = $false
    foreach ($policy in $policies) {
        if ($policy.conditions.userRiskLevels -and $policy.conditions.signInRiskLevels) {
            $result = $true
            $currentresult = $true
            $policiesResult.Add($policy) | Out-Null
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    $testDescription = "This test will check if both sign-in risk and user risk are configured in the same policy."

    if ( $result ) {
        $testResult = "The following conditional access policies have both sign-in risk and user risk controls configured:`n`n%TestResult%"
    } else {
        $testResult = "No conditional access policies detected where sign-in risk and user risk are combined."
    }
    Add-MtTestResultDetail -Description $testDescription -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}
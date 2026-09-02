function Test-MtCaMfaForAllUsers {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy requiring multifactor authentication for all users

    .Description
    MFA for all users Conditional Access policy can be used to require MFA for all users in the tenant.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa

    .Example
    Test-MtCaMfaForAllUsers

    .LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForAllUsers
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'AllUsers is a well known term for Conditional Access policies.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }
        # Remove policies that only require MFA in response to elevated risk (password change or risk
        # remediation grant control, or scoped via user/sign-in risk conditions), as those are conditional
        # on Identity Protection risk detections rather than requiring MFA on every sign-in.
        $policies = $policies | Where-Object {
            $_.grantControls.builtInControls -notcontains 'passwordChange' -and
            $_.grantControls.builtInControls -notcontains 'riskRemediation' -and
            -not $_.conditions.userRiskLevels -and
            -not $_.conditions.signInRiskLevels
        }
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
            $testResult = "The following Conditional Access policies require multi-factor authentication for all users:`n`n%TestResult%"
        } else {
            $testResult = 'No Conditional Access policy requires multi-factor authentication for all users.'
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $false
    }
}

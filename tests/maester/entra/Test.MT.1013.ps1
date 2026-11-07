function Test-MtCaRequirePasswordChangeForHighUserRisk {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy requiring password change for high user risk.

    .Description
    Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.

    The check is skipped when MT.1253 is met: an enabled policy that requires risk remediation for high user risk.
    Risk remediation replaces password change and also remediates users who sign in without a password.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user

    .Example
    Test-MtCaRequirePasswordChangeForHighUserRisk

    .LINK
    https://maester.dev/docs/commands/Test-MtCaRequirePasswordChangeForHighUserRisk
    #>
    [MaesterTest(
        Id = 'MT.1013',
        Title = 'At least one Conditional Access policy is configured to require new password when user risk is high.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-2(12)', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # Require risk remediation (MT.1253) is the higher maturity level of this requirement: when a policy meets it,
    # a password change policy is no longer needed. The same evaluation as MT.1253 decides, so the two never disagree.
    # If it cannot run (for example an EmergencyAccessAccounts entry that cannot be resolved), this check runs as before.
    try {
        $riskRemediation = Get-MtCaRiskRemediationPolicyResult -ErrorAction Stop
    } catch {
        Write-Verbose "Could not evaluate the risk remediation policies of MT.1253: $($_.Exception.Message)"
        $riskRemediation = $null
    }
    if ($riskRemediation -and $riskRemediation.Pass) {
        $passing = @($riskRemediation.Report | Where-Object { $_.Pass } | ForEach-Object { "'$($_.Policy.displayName)'" })
        $verb = if ($passing.Count -eq 1) { 'requires' } else { 'require' }
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "MT.1253 is met: $($passing -join ', ') $verb risk remediation for high user risk, which replaces the password change grant control."
        return $null
    }

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
        $testResult = "The following Conditional Access policies require password change for risky users`n`n%TestResult%"
    } else {
        $testResult = 'No Conditional Access policy requires a password change for risky users.'
    }
    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}

function Test-MtCaRequireRiskRemediationForHighUserRisk {
    <#
    .SYNOPSIS
    Checks if at least one enabled Conditional Access policy requires risk remediation for high-risk users.

    .DESCRIPTION
    The "Require risk remediation" grant control (riskRemediation) lets Microsoft Entra ID Protection pick the
    remediation flow that fits the user's risk and authentication method: a secure password change for
    password-based users, session revocation and a fresh sign-in for passwordless users, and disabling an
    attacker-added device. Unlike "Require password change", it also remediates users who sign in without a
    password.

    The check passes when at least one enabled Conditional Access policy:
    - includes all users, excluding only emergency access accounts and the guest/external-user selector,
    - targets all resources,
    - is scoped to the high user risk level (and to every lower level named by MinimumUserRiskLevel), and
    - requires the riskRemediation grant control.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/policy-risk-based-user#require-risk-remediation

    .EXAMPLE
    Test-MtCaRequireRiskRemediationForHighUserRisk

    .LINK
    https://maester.dev/docs/tests/MT.1253
    #>
    [MaesterTest(
        Id = 'MT.1253',
        Title = 'At least one Conditional Access policy is configured to require risk remediation when user risk is high.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = 'nist-800-53-r5:AC-2(12)',
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Lowest user risk level that a qualifying policy must cover; every higher level must be covered too.
        [ValidateSet('high', 'medium', 'low')]
        [string] $MinimumUserRiskLevel = 'high'
    )

    # The evaluation is shared with MT.1013, which is skipped when this requirement is met.
    $evaluation = Get-MtCaRiskRemediationPolicyResult -MinimumUserRiskLevel $MinimumUserRiskLevel
    $requiredRiskLevels = $evaluation.RequiredRiskLevels
    $policies = $evaluation.Policies
    $report = $evaluation.Report
    $emergencyUserIds = $evaluation.EmergencyUserIds
    $emergencyGroupIds = $evaluation.EmergencyGroupIds
    $emergencyAccessDetected = $evaluation.EmergencyAccessDetected
    $testResult = $evaluation.Pass

    $table = "| Policy | State | User risk levels | User exclusions | Failed checks | Result |`n"
    $table += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $policyLink = Get-GraphObjectMarkdown -GraphObjects $row.Policy -GraphObjectType ConditionalAccess -AsPlainTextLink
        $failedText = if ($row.Failed) { $row.Failed } else { 'None' }
        $resultText = if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }
        $table += "| $policyLink | $($row.Policy.state) | $($row.UserRiskLevels) | $($row.Exclusions) | $failedText | $resultText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. At least one enabled Conditional Access policy requires risk remediation for all users at user risk level $($requiredRiskLevels -join ', '), with only approved emergency access or guest/external-user exclusions.`n`n$table"
    } elseif ($report.Count -gt 0) {
        $testResultMarkdown = "No enabled Conditional Access policy requires risk remediation for all users and all resources at user risk level $($requiredRiskLevels -join ', '). These policies use the **Require risk remediation** grant control but do not meet every condition:`n`n$table"
    } else {
        $testResultMarkdown = 'No Conditional Access policy uses the **Require risk remediation** grant control.'
        $passwordChangePolicies = @($policies | Where-Object {
                $_.state -eq 'enabled' -and @($_.grantControls.builtInControls) -contains 'passwordChange'
            })
        if ($passwordChangePolicies.Count -gt 0) {
            $testResultMarkdown += " $($passwordChangePolicies.Count) enabled $(if ($passwordChangePolicies.Count -eq 1) { 'policy requires' } else { 'policies require' }) **Require password change** instead, which does not remediate users who sign in without a password. Consider replacing the grant control with **Require risk remediation**."
        }
    }
    if ($report.Count -gt 0 -and $emergencyAccessDetected) {
        $detected = @($emergencyUserIds | ForEach-Object { "user ``$_``" }) + @($emergencyGroupIds | ForEach-Object { "group ``$_``" })
        $testResultMarkdown += "`n`nEmergency access was detected automatically, because it is excluded from every Conditional Access policy: $($detected -join ', '). Set ``EmergencyAccessAccounts`` in maester-config.json to name the accounts and groups yourself."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}

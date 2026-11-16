function Test-MtCisaSpamAction {
    <#
    .SYNOPSIS
    Checks spam and phishing actions for the effective all-recipient policies.

    .DESCRIPTION
    Emails detected as spam and phishing SHALL NOT be delivered to the user's inbox.

    .EXAMPLE
    Test-MtCisaSpamAction

    Returns true when every active policy in the applicable precedence cascade uses actions that do not deliver messages to the inbox.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamAction
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.6.1',
        Title = 'Emails detected as spam and phishing SHALL NOT be delivered to the user''s inbox.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = 'cisa-scuba:MS.SECURITYSUITE.6.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policyEvaluation = Get-MtExoActiveSpamPolicyEvaluation -HasViolation {
        param($Policy)
        $inboxActions = @(
            $Policy.SpamAction,
            $Policy.HighConfidenceSpamAction,
            $Policy.PhishSpamAction,
            $Policy.HighConfidencePhishAction
        ) | Where-Object { $_ -notin @('MoveToJmf', 'Quarantine', 'Redirect', 'Delete') }
        $inboxActions.Count -gt 0
    }
    $activePolicies = $policyEvaluation.ActivePolicies

    $result = "| Active policy | Type | Spam | High-confidence spam | Phishing | High-confidence phishing | Result |`n"
    $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($policy in $activePolicies | Sort-Object -Property Identity) {
        $isFailing = $policy.Identity -in @($policyEvaluation.FailingPolicies | ForEach-Object { $_.Identity })
        $isShielded = if ($policy.IsDefault -eq $true) {
            $policyEvaluation.AnyPresetCompliant -or $policyEvaluation.AnyCustomCompliant
        } elseif ($policy.RecommendedPolicyType -eq 'Standard') {
            $policyEvaluation.StrictCompliant
        } elseif ($policy.RecommendedPolicyType -eq 'Custom') {
            $policyEvaluation.AnyPresetCompliant
        } else {
            $false
        }
        $status = if ($isFailing) { '❌ Fail' } elseif ($isShielded) { 'Not evaluated (shielded)' } else { '✅ Pass' }
        $policyType = if ($policy.IsDefault -eq $true) { 'Default' } else { $policy.RecommendedPolicyType }
        $result += "| $($policy.Identity) | $policyType | $($policy.SpamAction) | $($policy.HighConfidenceSpamAction) | $($policy.PhishSpamAction) | $($policy.HighConfidencePhishAction) | $status |`n"
    }
    if ($activePolicies.Count -eq 0) {
        $result += "| None | — | — | — | — | — | ❌ Fail |`n"
    }

    if ($policyEvaluation.TestResult) {
        $message = "Well done. $($policyEvaluation.CascadeStatus)`n`n%TestResult%"
    } else {
        $message = "One or more effective spam or phishing policies can deliver detected messages to the inbox. $($policyEvaluation.CascadeStatus)`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$policyEvaluation.TestResult
}

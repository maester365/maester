function Test-MtCisaSpamBypass {
    <#
    .SYNOPSIS
    Checks state of spam filter

    .DESCRIPTION
    Allowed domains SHALL NOT be added to inbound anti-spam protection policies.

    .EXAMPLE
    Test-MtCisaSpamBypass

    Returns true if spam filter enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamBypass
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.6.2',
        Title = 'Allowed domains SHALL NOT be added to inbound anti-spam protection policies.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.6.2',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policyEvaluation = Get-MtExoActiveSpamPolicyEvaluation -HasViolation {
        param($Policy)
        @($Policy.AllowedSenderDomains).Count -gt 0
    }
    $activePolicies = $policyEvaluation.ActivePolicies

    $result = "| Active policy | Type | Allowed domains | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
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
        $result += "| $($policy.Identity) | $policyType | $($policy.AllowedSenderDomains -join ', ') | $status |`n"
    }
    if ($activePolicies.Count -eq 0) {
        $result += "| None | — | — | ❌ Fail |`n"
    }

    if ($policyEvaluation.TestResult) {
        $message = "Well done. $($policyEvaluation.CascadeStatus)`n`n%TestResult%"
    } else {
        $message = "One or more effective inbound anti-spam policies have allowed sender domains. $($policyEvaluation.CascadeStatus)`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$policyEvaluation.TestResult
}

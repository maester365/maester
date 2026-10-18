function Test-MtCisMailForwardingBlocked {
    <#
    .SYNOPSIS
        Checks that mail flow rules and outbound spam policies do not forward mail to external recipients.

    .DESCRIPTION
        Checks that no transport rule redirects, copies or adds recipients for mail to an address outside the accepted domains, or to a target that cannot be shown to be internal, and that no outbound spam policy allows automatic forwarding to external recipients.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.2.1, L1)

    .EXAMPLE
        Test-MtCisMailForwardingBlocked

        Returns true if no rule or policy forwards mail externally.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.2.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.2.1',
        Title = 'Ensure all forms of mail forwarding are blocked and/or disabled',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'mail-flow',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1114.003',
        Control = ('cis-m365:6.2.1', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting mail flow rules and outbound spam policies...'
    $acceptedDomains = @(Get-MtExo -Request AcceptedDomain | ForEach-Object { "$($_.DomainName)".Trim().TrimEnd('.') })
    $transportRules = @(Get-MtExo -Request TransportRule)
    $outboundPolicies = @(Get-MtExo -Request HostedOutboundSpamFilterPolicy)

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($rule in $transportRules) {
        foreach ($action in 'RedirectMessageTo', 'BlindCopyTo', 'CopyTo', 'AddToRecipients') {
            foreach ($address in @($rule.$action | Where-Object { $_ })) {
                $text = "$address".Trim()
                $at = $text.LastIndexOf('@')
                if ($at -lt 0) {
                    $findings.Add([pscustomobject]@{ Source = "Transport rule: $($rule.Name)"; Detail = "$text in $action (target cannot be verified as internal)" })
                } elseif ($acceptedDomains -notcontains $text.Substring($at + 1).TrimEnd('.')) {
                    $findings.Add([pscustomobject]@{ Source = "Transport rule: $($rule.Name)"; Detail = "$text in $action (external)" })
                }
            }
        }
    }
    foreach ($policy in $outboundPolicies) {
        if ($policy.AutoForwardingMode -ne 'Off') {
            $findings.Add([pscustomobject]@{ Source = "Outbound spam policy: $($policy.Name)"; Detail = "Automatic forwarding is $($policy.AutoForwardingMode)" })
        }
    }
    $testResult = $findings.Count -eq 0

    $passText = 'No mail flow rule or outbound spam policy forwards mail to external recipients.'
    $failText = "$($findings.Count) forwarding configuration(s) can send mail to external recipients."

    $resultMd = "| Source | Detail | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($finding in $findings) {
        $resultMd += "| $($finding.Source) | $($finding.Detail) | ❌ Fail |`n"
    }
    if ($testResult) {
        $resultMd = "| Forwarding configurations to external recipients | Result |`n| --- | --- |`n| 0 | ✅ Pass |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}

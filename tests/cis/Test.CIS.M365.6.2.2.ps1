function Test-MtCisTransportRulesNoDomainAllowList {
    <#
    .SYNOPSIS
        Checks that no mail flow rule bypasses spam filtering for specific sender domains.

    .DESCRIPTION
        Lists mail flow rules that set the spam confidence level to -1 for messages from specific sender domains and passes when there are none. Those rules skip spam and phishing filtering for the domain.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.2.2, L1)

    .EXAMPLE
        Test-MtCisTransportRulesNoDomainAllowList

        Returns true if no mail flow rule bypasses spam filtering for specific domains.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.2.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.2.2',
        Title = 'Ensure mail transport rules do not whitelist specific domains',
        Product = 'exchange',
        Feature = 'mail-flow',
        Area = 'email-protection',
        ResourceType = 'MailFlowRule',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:6.2.2', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting mail flow rules...'
    $rules = @(Get-MtExo -Request TransportRule)
    $failed = @($rules | Where-Object { $_.SetSCL -eq -1 -and @($_.SenderDomainIs).Count -gt 0 })
    $testResult = $failed.Count -eq 0

    $passText = 'No mail flow rule bypasses spam filtering for specific domains.'
    $failText = "$($failed.Count) mail flow rule(s) bypass spam filtering for specific domains."

    $resultMd = "| Rule | Sender domains | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($rule in $failed) {
        $resultMd += "| $($rule.Name) | $(@($rule.SenderDomainIs) -join ', ') | ❌ Fail |`n"
    }
    if ($testResult) {
        $resultMd = "| Rules that bypass spam filtering for domains | Result |`n| --- | --- |`n| 0 | ✅ Pass |`n"
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

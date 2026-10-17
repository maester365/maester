function Test-MtCisAntiSpamAllowedDomains {
    <#
    .SYNOPSIS
        Checks that no inbound anti-spam policy has allowed sender domains.

    .DESCRIPTION
        Checks every inbound anti-spam policy and passes when none of them lists allowed sender domains. Mail from an allowed domain skips spam filtering, so a spoofed sender from that domain is delivered.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.14, L1)

    .EXAMPLE
        Test-MtCisAntiSpamAllowedDomains

        Returns true if no inbound anti-spam policy has allowed sender domains.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.1.14
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.14',
        Title = 'Ensure inbound anti-spam policies do not contain allowed domains',
        Product = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.14', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting inbound anti-spam policies...'
    $policies = @(Get-MtExo -Request HostedContentFilterPolicy)

    $report = foreach ($policy in $policies) {
        $allowed = @($policy.AllowedSenderDomains | Where-Object { $_ })
        [pscustomobject]@{ Name = $policy.Identity; Count = $allowed.Count; Domains = ($allowed -join ', '); Pass = $allowed.Count -eq 0 }
    }
    $failed = @($report | Where-Object { -not $_.Pass })
    $testResult = $failed.Count -eq 0

    $passText = 'No inbound anti-spam policy contains allowed sender domains.'
    $failText = "$($failed.Count) inbound anti-spam policy(ies) contain allowed sender domains."

    $resultMd = "| Policy | Allowed sender domains | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $(if ($row.Count -gt 0) { $row.Domains } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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

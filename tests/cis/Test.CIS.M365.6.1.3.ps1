function Test-MtCisMailboxAuditBypass {
    <#
    .SYNOPSIS
        Checks that no account bypasses mailbox auditing.

    .DESCRIPTION
        Lists the accounts for which mailbox audit logging is bypassed and passes when there are none. An account with audit bypass can read and change mailboxes without leaving an audit record.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.1.3, L1)

    .EXAMPLE
        Test-MtCisMailboxAuditBypass

        Returns true if no account has mailbox audit bypass enabled.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.1.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.1.3',
        Title = 'Ensure ''AuditBypassEnabled'' is not enabled on mailboxes',
        Product = 'exchange',
        Feature = 'mailbox-auditing',
        Area = 'logging-and-detection',
        ResourceType = 'Mailbox',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1685.002',
        Control = ('cis-m365:6.1.3', 'nist-800-53-r5:AU-12'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting mailbox audit bypass associations...'
    $associations = @(Get-MtExo -Request MailboxAuditBypassAssociation)
    $bypassed = @($associations | Where-Object { $_.AuditBypassEnabled -eq $true })
    $testResult = $bypassed.Count -eq 0

    $passText = 'No account bypasses mailbox auditing.'
    $failText = "$($bypassed.Count) account(s) bypass mailbox auditing."

    $resultMd = "| Account | AuditBypassEnabled | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($row in ($bypassed | Select-Object -First 50)) {
        $resultMd += "| $($row.Identity) | $($row.AuditBypassEnabled) | ❌ Fail |`n"
    }
    if ($bypassed.Count -gt 50) {
        $resultMd += "`nShowing 50 of $($bypassed.Count) accounts."
    }
    if ($testResult) {
        $resultMd = "| Accounts with audit bypass | Result |`n| --- | --- |`n| 0 | ✅ Pass |`n"
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

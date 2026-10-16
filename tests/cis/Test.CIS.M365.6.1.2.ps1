function Test-MtCisMailboxAuditActions {
    <#
    .SYNOPSIS
        Checks that user mailboxes audit the recommended admin, delegate and owner actions.

    .DESCRIPTION
        Checks every user mailbox and passes when auditing is enabled and the audited actions for administrators, delegates and owners include the recommended set, including MailItemsAccessed and the actions that change mail and rules.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.1.2, L1)

    .EXAMPLE
        Test-MtCisMailboxAuditActions

        Returns true if all user mailboxes audit the recommended actions.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.1.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.1.2',
        Title = 'Ensure mailbox audit actions are configured',
        Product = 'exchange',
        Feature = 'mailbox-auditing',
        Area = 'logging-and-detection',
        ResourceType = 'Mailbox',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1685.002',
        Control = ('cis-m365:6.1.2', 'nist-800-53-r5:AU-12'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting user mailbox audit settings...'
    $adminActions = @('ApplyRecord', 'Copy', 'Create', 'FolderBind', 'HardDelete', 'MailItemsAccessed', 'Move', 'MoveToDeletedItems', 'SendAs', 'SendOnBehalf', 'Send', 'SoftDelete', 'Update', 'UpdateCalendarDelegation', 'UpdateFolderPermissions', 'UpdateInboxRules')
    $delegateActions = @('ApplyRecord', 'Create', 'FolderBind', 'HardDelete', 'Move', 'MailItemsAccessed', 'MoveToDeletedItems', 'SendAs', 'SendOnBehalf', 'SoftDelete', 'Update', 'UpdateFolderPermissions', 'UpdateInboxRules')
    $ownerActions = @('ApplyRecord', 'Create', 'HardDelete', 'MailboxLogin', 'Move', 'MailItemsAccessed', 'MoveToDeletedItems', 'Send', 'SoftDelete', 'Update', 'UpdateCalendarDelegation', 'UpdateFolderPermissions', 'UpdateInboxRules')
    $mailboxes = @(Get-MtExo -Request EXOMailboxAudit)

    $report = foreach ($mailbox in $mailboxes) {
        $missingAdmin = @($adminActions | Where-Object { @($mailbox.AuditAdmin) -notcontains $_ })
        $missingDelegate = @($delegateActions | Where-Object { @($mailbox.AuditDelegate) -notcontains $_ })
        $missingOwner = @($ownerActions | Where-Object { @($mailbox.AuditOwner) -notcontains $_ })
        if (-not $mailbox.AuditEnabled -or $missingAdmin.Count -gt 0 -or $missingDelegate.Count -gt 0 -or $missingOwner.Count -gt 0) {
            [pscustomobject]@{
                Mailbox = $mailbox.UserPrincipalName
                AuditEnabled = $mailbox.AuditEnabled
                MissingAdmin = $missingAdmin.Count
                MissingDelegate = $missingDelegate.Count
                MissingOwner = $missingOwner.Count
            }
        }
    }
    $failed = @($report)
    $testResult = $failed.Count -eq 0

    $passText = "All $($mailboxes.Count) user mailboxes audit the recommended actions."
    $failText = "$($failed.Count) of $($mailboxes.Count) user mailboxes do not audit all the recommended actions."

    $resultMd = "| Mailbox | Auditing enabled | Missing admin actions | Missing delegate actions | Missing owner actions |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in ($failed | Select-Object -First 50)) {
        $resultMd += "| $($row.Mailbox) | $($row.AuditEnabled) | $($row.MissingAdmin) | $($row.MissingDelegate) | $($row.MissingOwner) |`n"
    }
    if ($failed.Count -gt 50) {
        $resultMd += "`nShowing 50 of $($failed.Count) mailboxes."
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
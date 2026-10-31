Mailbox auditing is switched on organisation-wide in Exchange Online.

Mailbox audit logs record who accessed a mailbox and what they did: logons, reads, moves, deletions and rule changes. They are the evidence that is needed to investigate a business email compromise. With auditing off for the organisation, mailbox owners, delegates and administrators leave no trace.

Mailbox auditing is on by default. Someone has to turn it off deliberately, so a failure here deserves investigation as well as a fix.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OrganizationConfig -AuditDisabled $false`.
3. Check the result with `Get-OrganizationConfig | Format-List AuditDisabled`.

#### Related links

* [Manage mailbox auditing](https://learn.microsoft.com/purview/audit-mailboxes)
* [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchange/set-organizationconfig)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.1.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

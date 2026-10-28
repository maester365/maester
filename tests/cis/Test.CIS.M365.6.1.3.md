No account is configured to bypass mailbox audit logging.

Audit bypass is meant for service accounts that generate a lot of noise, such as a monitoring or journaling account. Anything such an account does in any mailbox is not logged. An attacker or a malicious administrator with an account on the bypass list can read and change mail with no record in the audit log.

Remove the bypass from every account and reduce the noise in another way, for example by filtering the audit log when you search it.

> **Note:** This test is `LongRunning`. It reads the audit bypass setting of every mailbox and recipient, which can take a long time in large tenants. Use `Invoke-Maester -IncludeLongRunning` to run it, or select it by ID.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. List the accounts with `Get-MailboxAuditBypassAssociation -ResultSize Unlimited | Where-Object { $_.AuditBypassEnabled }`.
3. For each account run `Set-MailboxAuditBypassAssociation -Identity <account> -AuditBypassEnabled $false`.

#### Related links

* [Manage mailbox auditing](https://learn.microsoft.com/purview/audit-mailboxes)
* [Set-MailboxAuditBypassAssociation](https://learn.microsoft.com/powershell/module/exchange/set-mailboxauditbypassassociation)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.1.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

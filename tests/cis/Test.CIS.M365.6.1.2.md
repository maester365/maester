Every user mailbox audits the recommended set of actions for administrators, delegates and mailbox owners.

Exchange Online audits a default set of actions. Some actions that matter in an investigation, such as MailItemsAccessed, which shows which messages an attacker read, and the actions that change inbox rules and folder permissions, are not part of every default set, or an administrator may have reduced the list.

The test looks at all user mailboxes and lists those that have auditing disabled or miss one of the recommended actions. A listed mailbox needs the recommended actions added to its own audit settings. Microsoft Purview Audit (Standard) is enough for the default set, and MailItemsAccessed needs a licence that includes Audit (Premium) for some users.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Get-EXOMailbox -RecipientTypeDetails UserMailbox -PropertySets Audit,Minimum` to see the audit settings of your mailboxes.
3. Add the recommended actions to each mailbox that is listed, with `Set-Mailbox -Identity <user> -AuditAdmin @{Add=<actions>} -AuditDelegate @{Add=<actions>} -AuditOwner @{Add=<actions>}`. The `Add` value appends the actions to the current list and does not remove others.
4. Make sure that no mailbox has `AuditEnabled` set to false.

#### Related links

* [Manage mailbox auditing](https://learn.microsoft.com/purview/audit-mailboxes)
* [Set-Mailbox](https://learn.microsoft.com/powershell/module/exchange/set-mailbox)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.1.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

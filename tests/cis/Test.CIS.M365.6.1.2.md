Every user mailbox audits the recommended set of actions for administrators, delegates and mailbox owners.

Exchange Online audits a default set of actions. Some actions that matter in an investigation, such as MailItemsAccessed, which shows which messages an attacker read, and the actions that change inbox rules and folder permissions, are not part of every default set, or an administrator may have reduced the list.

The test looks at all user mailboxes and lists those that have auditing disabled or miss one of the recommended actions. A listed mailbox needs the recommended actions added to its own audit settings. If the tenant has no user mailboxes, the check is not applicable and is skipped. Microsoft Purview Audit (Standard) is enough for the default set, and MailItemsAccessed needs a licence that includes Audit (Premium) for some users.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run the following script to add the CIS audit actions to every user mailbox while preserving any additional actions already configured. It also enables auditing and sets the audit log age limit to 180 days as shown in the CIS remediation procedure.

```powershell
$AuditAdmin = @(
	'ApplyRecord', 'Copy', 'Create', 'FolderBind', 'HardDelete',
	'MailItemsAccessed', 'Move', 'MoveToDeletedItems', 'SendAs',
	'SendOnBehalf', 'Send', 'SoftDelete', 'Update',
	'UpdateCalendarDelegation', 'UpdateFolderPermissions', 'UpdateInboxRules'
)
$AuditDelegate = @(
	'ApplyRecord', 'Create', 'FolderBind', 'HardDelete', 'Move',
	'MailItemsAccessed', 'MoveToDeletedItems', 'SendAs', 'SendOnBehalf',
	'SoftDelete', 'Update', 'UpdateFolderPermissions', 'UpdateInboxRules'
)
$AuditOwner = @(
	'ApplyRecord', 'Create', 'HardDelete', 'MailboxLogin', 'Move',
	'MailItemsAccessed', 'MoveToDeletedItems', 'Send', 'SoftDelete',
	'Update', 'UpdateCalendarDelegation', 'UpdateFolderPermissions', 'UpdateInboxRules'
)
$Mailboxes = Get-EXOMailbox -RecipientTypeDetails UserMailbox -PropertySets Audit,Minimum -ResultSize Unlimited

foreach ($Mailbox in $Mailboxes) {
	Set-Mailbox -Identity $Mailbox.UserPrincipalName `
		-AuditEnabled $true `
		-AuditLogAgeLimit 180 `
		-AuditAdmin @{ Add = $AuditAdmin } `
		-AuditDelegate @{ Add = $AuditDelegate } `
		-AuditOwner @{ Add = $AuditOwner }
}
```

3. Check the result with `Get-EXOMailbox -RecipientTypeDetails UserMailbox -PropertySets Audit,Minimum -ResultSize Unlimited` and confirm `AuditEnabled` and the required actions are present.

#### Related links

* [Manage mailbox auditing](https://learn.microsoft.com/purview/audit-mailboxes)
* [Set-Mailbox](https://learn.microsoft.com/powershell/module/exchange/set-mailbox)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.1.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

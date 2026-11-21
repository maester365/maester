This check evaluates legacy application access policies in Exchange Online for applications with Microsoft Graph mail permissions.

These permissions grant access to every mailbox unless an application access policy restricts them.

Microsoft Exchange related permissions that should be secured by application access policies include:

- Mail.Read
- Mail.ReadBasic
- Mail.ReadBasic.All
- Mail.ReadWrite
- Mail.Send
- MailboxSettings.Read
- MailboxSettings.ReadWrite
- Calendars.Read
- Calendars.ReadWrite
- Contacts.Read
- Contacts.ReadWrite

This check requires a `RestrictAccess` policy for each application. A `DenyAccess` policy only denies access to mailboxes in its scope; it does not restrict access to mailboxes outside that scope and does not satisfy this check.

### Remediation action

Microsoft has replaced application access policies with [RBAC for Applications](https://learn.microsoft.com/exchange/permissions-exo/application-rbac) and advises against creating new application access policies.

1. For an app still using legacy policies, review its existing policies and confirm a matching `RestrictAccess` policy limits it to the intended mailboxes. A deny-only policy does not provide that limit.
2. For new configurations or migration, follow Microsoft's RBAC for Applications guide to assign the required Exchange application role with a mailbox scope.
3. Remove equivalent or broader Microsoft Graph application permissions from the app's Entra grants after migration. Entra and Exchange grants are additive; retaining an unscoped Entra grant defeats the Exchange scope. See [MT.1252](https://maester.dev/docs/tests/MT.1252) for overlapping grants.
4. Verify the app against both an intended mailbox and a mailbox outside its scope. `Test-ServicePrincipalAuthorization` evaluates the Exchange RBAC assignment; it does not include separate Entra grants.

MT.1058 does not evaluate RBAC assignments. An app whose mail permissions are granted only through Exchange RBAC is outside this check's scope.

For existing application access policies, inspect and test the policy configuration with:

```powershell
Connect-ExchangeOnline
Get-ApplicationAccessPolicy
Test-ApplicationAccessPolicy -Identity user@contoso.com -AppId '<your-app-id>'
```

#### Related links

- [Application access policy replacement notice - Microsoft Learn](https://learn.microsoft.com/powershell/module/exchangepowershell/new-applicationaccesspolicy)
- [RBAC for Applications in Exchange Online - Microsoft Learn](https://learn.microsoft.com/exchange/permissions-exo/application-rbac)

<!--- Results --->
%TestResult%

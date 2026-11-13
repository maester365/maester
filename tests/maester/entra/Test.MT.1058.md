This check evaluates legacy application access policies in Exchange Online for applications with Microsoft Graph mail permissions or the Exchange Web Services (EWS) permission `full_access_as_app`.

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
- full_access_as_app (Office 365 Exchange Online)

Each permission is matched on the API that defines it. `full_access_as_app` gives access to every mailbox through EWS, which Microsoft is retiring in Exchange Online; it matters wherever EWS is still enabled.

An app role assignment to one of these two APIs that names a role the API does not define is listed under **App Role Assignments Not Evaluated**. When nothing else fails, the result is marked for investigation instead of passing. `Test-MtSpExchangeAppAccessPolicy` still returns `$true` in that case, so a script that reads only its return value sees a pass.

This check requires a `RestrictAccess` policy for each application; a `RestrictAccess` policy created with `-AppId *` applies to every application. A `DenyAccess` policy only denies access to mailboxes in its scope; it does not restrict access to mailboxes outside that scope and does not satisfy this check.

### Remediation action

Microsoft has replaced application access policies with [RBAC for Applications](https://learn.microsoft.com/exchange/permissions-exo/application-rbac) and advises against creating new application access policies.

1. For an app still using legacy policies, review its existing policies and confirm a matching `RestrictAccess` policy limits it to the intended mailboxes. A deny-only policy does not provide that limit.
2. For new configurations or migration, follow Microsoft's RBAC for Applications guide to assign the required Exchange application role with a mailbox scope.
3. Remove equivalent or broader application permissions (Microsoft Graph, or `full_access_as_app` for EWS) from the app's Entra grants after migration. Entra and Exchange grants are additive; retaining an unscoped Entra grant defeats the Exchange scope. See [MT.1252](https://maester.dev/docs/tests/MT.1252) for overlapping grants.
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
- [Application access policies: supported permissions - Microsoft Learn](https://learn.microsoft.com/exchange/permissions-exo/application-access-policies#supported-permissions-and-other-resources)
- [RBAC for Applications in Exchange Online - Microsoft Learn](https://learn.microsoft.com/exchange/permissions-exo/application-rbac)
- [Exchange Online EWS retirement - Exchange Team Blog](https://techcommunity.microsoft.com/blog/exchange/exchange-online-ews-your-time-is-almost-up/4492361)

<!--- Results --->
%TestResult%

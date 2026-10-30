When external sharing is turned on, every user who can share SharePoint and OneDrive content can also share it with people outside the organization. If an account is compromised, the attacker gets the same right and can send files to an outside address.

Limiting external sharing to members of specific security groups means only the people in those groups can share with external users. Other users can still work with their files and sites, but they cannot share them externally until they are added to a group. The members must also be allowed to invite guests in the Microsoft Entra external collaboration settings.

Microsoft Entra organizational relationship settings, such as **Members can invite** and **Guests can invite**, can be more restrictive than SharePoint and take precedence for B2B invitations. This test checks the SharePoint group allowlist only; it does not verify those tenant-wide Entra settings.

#### Remediation action

1. Create or choose a Microsoft Entra security group that contains the users who are allowed to share externally. Microsoft 365 groups are not accepted.
2. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
3. Go to **Policies** > **Sharing**.
4. Expand **More external sharing settings**.
5. Select **Allow only users in specific security groups to share externally**, then select **Manage security groups**.
6. Add the group (up to 12 groups can be added). Under **Can share with**, keep **Authenticated guests only** (the default). A group set to **Anyone** can also share Anyone links, which need no sign-in, so it does not satisfy this check. At least one group must be set to **Authenticated guests only**.
7. Select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run the following, replacing the placeholder with the object ID of your security group. The list you pass replaces the current one. The check reads this list, as the CIS PowerShell audit does. Groups in -WhoCanShareAnonymousAllowList (set to **Anyone** in the admin center) are shown in the results but do not count.

```powershell
Set-PnPTenant -WhoCanShareAuthenticatedGuestAllowList '<group object id>'
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [External sharing overview](https://learn.microsoft.com/sharepoint/external-sharing-overview)
* [Allow only members in specific security groups to share SharePoint and OneDrive files and folders externally](https://learn.microsoft.com/sharepoint/manage-security-groups)
* [Microsoft Entra B2B integration for SharePoint and OneDrive](https://learn.microsoft.com/sharepoint/sharepoint-azureb2b-integration)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

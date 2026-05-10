1.3.3 (L2) Ensure 'External sharing' of calendars is not available

External calendar sharing allows an administrator to enable the ability for users to share calendars with anyone outside of the organization. Outside users will be sent a URL that can be used to view the calendar.

#### Rationale

Attackers often spend time learning about organizations before launching an attack. Publicly available calendars can help attackers understand organizational relationships and determine when specific users may be more vulnerable to an attack, such as when they are traveling.

#### Impact

This functionality is not widely used. As a result, it is unlikely that implementation of this setting will cause an impact to most users. Users that do utilize this functionality are likely to experience a minor inconvenience when scheduling meetings or synchronizing calendars with people outside the tenant.

#### Remediation action:

To remediate using the UI:
1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Click to expand **Settings** select **Org settings**.
3. In the **Services** section click **Calendar**.
4. Uncheck **Let your users share their calendars with people outside of your organization who have Office 365 or Exchange**.
5. Click **Save**.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following Exchange Online PowerShell command:
```powershell
Set-SharingPolicy -Identity "Default Sharing Policy" -Enabled $False
```


#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Share Microsoft 365 calendars with people outside your organization](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/share-calendars-with-external-users?view=o365-worldwide)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 53](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
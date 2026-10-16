Guests who sign in with a one-time verification code prove access by reading an email sent to their address. If the verification is not repeated for a long time, a guest whose mailbox or account has been compromised keeps access to shared SharePoint content without a new check.

Requiring guests to verify again every 15 days or less limits how long a stale or compromised guest account keeps working. Guests sign in again with a new code each time, which is a small extra step for them.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Under **Guests must sign in using the same account to which sharing invitations are sent**, make sure the setting is on.
5. Set the number of days before people must verify again to **15** or fewer and select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run:

```powershell
Set-PnPTenant -EmailAttestationRequired $true -EmailAttestationReAuthDays 15
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Email one-time passcode authentication for B2B guest users](https://learn.microsoft.com/entra/external-id/one-time-passcode)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

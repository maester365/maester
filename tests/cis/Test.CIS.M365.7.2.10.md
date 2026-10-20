Guests who sign in with a one-time verification code prove access by reading an email sent to their address. If the verification is not repeated for a long time, a guest whose mailbox or account has been compromised keeps access to shared SharePoint content without a new check.

Requiring guests to verify again every 15 days or less limits how long a stale or compromised guest account keeps working. Guests sign in again with a new code each time, which is a small extra step for them.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Select **People who use a verification code must reauthenticate after this many days** and enter **15** or fewer.
5. Select **Save**.

When SharePoint and OneDrive integration with Microsoft Entra B2B is turned on (CIS 7.2.2), Microsoft Entra guest settings take precedence over this setting for new guests. This test still audits the SharePoint values as defined by CIS 7.2.10. See CIS 5.2.3.7 for the recommended Email OTP configuration.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run:

```powershell
Set-PnPTenant -EmailAttestationRequired $true -EmailAttestationReAuthDays 15
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Manage sharing settings for SharePoint and OneDrive in Microsoft 365](https://learn.microsoft.com/sharepoint/turn-external-sharing-on-or-off)
* [Email one-time passcode authentication for B2B guest users](https://learn.microsoft.com/entra/external-id/one-time-passcode)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

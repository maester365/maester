Modern authentication is enabled for Exchange Online.

The `OAuth2ClientProfileEnabled` setting turns on modern authentication for supported Outlook for Windows clients (Outlook 2013 and later). It allows these clients to support multifactor authentication and Conditional Access. If it is turned off, these Outlook connections can fail to sign in, because Exchange Online no longer supports basic authentication for them.

It is on by default for tenants created after August 2017. For older tenants, or if someone turned it off, enable it.

#### Remediation action

To enable modern authentication in the Microsoft 365 admin center:

1. Go to [Microsoft 365 admin center > Settings > Org settings > Modern authentication](https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/ModernAuthentication).
2. Select **Turn on modern authentication for Outlook 2013 for Windows and later (recommended)**.
3. Select **Save**.

To enable modern authentication with PowerShell:

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OrganizationConfig -OAuth2ClientProfileEnabled $true`.
3. Check the setting with `Get-OrganizationConfig | Format-List OAuth2ClientProfileEnabled`.

#### Related links

* [Microsoft 365 admin center - Modern authentication](https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/ModernAuthentication)
* [Enable or disable modern authentication for Outlook in Exchange Online](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/enable-or-disable-modern-authentication-in-exchange-online)
* [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchange/set-organizationconfig)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

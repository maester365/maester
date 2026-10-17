Modern authentication is enabled for Exchange Online.

Modern authentication lets Outlook and other clients sign in with tokens, supports multifactor authentication and Conditional Access, and does not send passwords to the server on every request. Without it, clients fall back to basic authentication, where the password is the only protection.

It is on by default for tenants created after August 2017. For older tenants, or if someone turned it off, enable it.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OrganizationConfig -OAuth2ClientProfileEnabled $true`.
3. Check the setting with `Get-OrganizationConfig | Format-List OAuth2ClientProfileEnabled`.

#### Related links

* [Enable or disable modern authentication for Outlook in Exchange Online](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/enable-or-disable-modern-authentication-in-exchange-online)
* [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchange/set-organizationconfig)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

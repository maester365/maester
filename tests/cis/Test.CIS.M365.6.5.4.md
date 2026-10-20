Authenticated SMTP submission (SMTP AUTH) is turned off for the whole organisation.

SMTP AUTH is used by scanners, applications and older mail clients to send mail. It supports both basic authentication and OAuth. When it is used with basic authentication, it cannot be protected with MFA, and it is a common target for password spray and for sending spam from a compromised mailbox.

Turning off SMTP AUTH blocks all SMTP AUTH submissions, including those that use OAuth. Before you disable it, find the devices and applications that still use it, for example with the SMTP AUTH client submission report. Then move them to a different submission method, such as SMTP relay with a connector, High Volume Email, or the Microsoft Graph API with OAuth. You can turn SMTP AUTH back on for single mailboxes that must keep it.

#### Remediation action

To turn off SMTP AUTH in the Exchange admin center:

1. Go to [Exchange admin center > Settings > Mail flow](https://admin.exchange.microsoft.com/#/settings).
2. Select **Turn off SMTP AUTH protocol for your organization**.
3. Select **Save**.

To turn off SMTP AUTH with PowerShell:

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-TransportConfig -SmtpClientAuthenticationDisabled $true`.
3. Check the setting with `Get-TransportConfig | Format-List SmtpClientAuthenticationDisabled`.

#### Related links

* [Exchange admin center - Mail flow settings](https://admin.exchange.microsoft.com/#/settings)
* [Enable or disable authenticated client SMTP submission (SMTP AUTH)](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/authenticated-client-smtp-submission)
* [How to set up a multifunction device or application to send email](https://learn.microsoft.com/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

Authenticated SMTP submission (SMTP AUTH) is turned off for the whole organisation.

SMTP AUTH is used by scanners, applications and older mail clients to send mail with a username and password. It supports only basic authentication, so it cannot be protected with MFA and is a popular target for password spray and for sending spam from a compromised mailbox.

Before you disable it, find the devices and applications that still use it, for example by looking at the SMTP AUTH client submission report, and move them to an alternative such as SMTP relay with a connector, High Volume Email or OAuth. You can enable it again for single mailboxes that must keep it.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-TransportConfig -SmtpClientAuthenticationDisabled $true`.
3. Check the setting with `Get-TransportConfig | Format-List SmtpClientAuthenticationDisabled`.

#### Related links

* [Enable or disable authenticated client SMTP submission (SMTP AUTH)](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/authenticated-client-smtp-submission)
* [How to set up a multifunction device or application to send email](https://learn.microsoft.com/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

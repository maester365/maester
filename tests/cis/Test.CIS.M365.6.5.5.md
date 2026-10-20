Exchange Online rejects Direct Send submissions: unauthenticated messages sent to your tenant where the envelope sender (MAIL FROM) domain is one of your accepted domains and no eligible inbound connector matches the message.

Direct Send lets a device or application send mail to your tenant, from an address in your own domain, without signing in. Attackers use the same path to send phishing that looks like internal mail. When `RejectDirectSend` is turned on, Exchange Online rejects these messages instead of delivering them. It does not reject every anonymous message that shows an internal sender address. For example, a message can use an external envelope sender and still show one of your addresses in the From header. Anti-spoofing controls such as SPF, DKIM, DMARC and spoof intelligence are still needed for those messages.

Before you turn it on, find the devices and applications that rely on Direct Send, for example printers and scanners. Move them to authenticated SMTP submission, SMTP relay with a connector or High Volume Email.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OrganizationConfig -RejectDirectSend $true`.
3. Check the setting with `Get-OrganizationConfig | Format-List RejectDirectSend`.

#### Related links

* [Direct Send: Send mail directly from your device or application to Microsoft 365](https://learn.microsoft.com/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365#direct-send-send-mail-directly-from-your-device-or-application-to-microsoft-365-or-office-365)
* [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchange/set-organizationconfig)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

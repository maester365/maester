Exchange Online rejects Direct Send submissions: messages that are sent without authentication to your own mail endpoint, using an internal sender address.

Direct Send lets a device or application send mail to your tenant, from an address in your own domain, without signing in. Attackers use the same path to send phishing that looks like internal mail. Rejecting it removes the path.

Before you turn it on, find the devices and applications that rely on Direct Send, for example printers and scanners, and move them to authenticated SMTP submission, SMTP relay with a connector or High Volume Email.

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

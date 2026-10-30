Outlook marks messages that come from outside the organisation with an External tag.

Phishing often impersonates a colleague, with a display name that matches an internal person. A clear External tag next to the sender tells the reader that the message is from outside and gives them a prompt to be careful before clicking a link or paying an invoice.

The feature works in Outlook for Windows, Mac, on the web and on mobile. You can add trusted senders to an exception list, but the more entries it has, the fewer messages are tagged.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-ExternalInOutlook -Enabled $true`.
3. Check the setting with `Get-ExternalInOutlook`.

#### Related links

* [Set-ExternalInOutlook](https://learn.microsoft.com/powershell/module/exchange/set-externalinoutlook)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

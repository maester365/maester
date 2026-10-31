MailTips are enabled, including tips for external recipients and for large audiences.

MailTips show a short warning in the message while it is being written, for example that a recipient is outside the organisation or that the message goes to a large group. The warning prevents misdirected mail and gives the user a chance to stop a message that would leak data.

The test needs all MailTips on, the external recipient tip on, group metrics on and a large audience threshold greater than zero.

CIS does not prescribe one threshold for every organization: its PowerShell audit procedure asks administrators to verify an acceptable value and notes that `25` is the default. This check reports the configured value and only rejects an unset or nonpositive threshold; confirm that any other positive value is suitable for your organization.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OrganizationConfig -MailTipsAllTipsEnabled $true -MailTipsExternalRecipientsTipsEnabled $true -MailTipsGroupMetricsEnabled $true -MailTipsLargeAudienceThreshold 25`.
3. Check the settings with `Get-OrganizationConfig | Format-List MailTips*`.

#### Related links

* [MailTips in Exchange Online](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/mailtips/mailtips)
* [Set-OrganizationConfig](https://learn.microsoft.com/powershell/module/exchange/set-organizationconfig)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.5.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

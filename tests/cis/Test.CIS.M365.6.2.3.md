Outlook marks messages that come from outside the organisation with an External tag.

Phishing often impersonates a colleague, with a display name that matches an internal person. A clear External tag next to the sender tells the reader that the message is from outside and gives them a prompt to be careful before clicking a link or paying an invoice.

The feature works in Outlook for Windows, Mac, on the web and on mobile. CIS requires the allow list to contain only email addresses the organization has permitted to bypass external tagging. When external sender identification is enabled and the allow list is nonempty, this test reports **Investigate** so an administrator can confirm each address is approved; it cannot infer authorization from the address itself.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Get-ExternalInOutlook` and review every `AllowList` entry. Remove entries that are not explicitly approved by your organization.
3. Remove an unapproved entry with `Set-ExternalInOutlook -AllowList @{Remove='address@domain.com'}`, or replace the list with `Set-ExternalInOutlook -AllowList $ApprovedAddresses` after setting `$ApprovedAddresses` to the approved email addresses.
4. Run `Set-ExternalInOutlook -Enabled $true`.
5. Check the settings with `Get-ExternalInOutlook`.

#### Related links

* [Set-ExternalInOutlook](https://learn.microsoft.com/powershell/module/exchange/set-externalinoutlook)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

The default Outlook on the web mailbox policy does not allow connecting personal email accounts and personal calendars.

When a user connects a personal mail account, company and private mail mix in one inbox, and content can be moved or copied between them without any of your data protection controls applying. Mail from the personal account is also not filtered by your anti-phishing protection, which makes it a way to deliver malicious content.

Disabling the setting prevents users from adding the accounts in Outlook on the web and the new Outlook.

#### Remediation action

1. Connect to Exchange Online with `Connect-ExchangeOnline`.
2. Run `Set-OwaMailboxPolicy -Identity OwaMailboxPolicy-Default -PersonalAccountsEnabled $false -PersonalAccountCalendarsEnabled $false`. The test checks only the default policy, so also run the same command for each custom policy that users are assigned and that `Get-OwaMailboxPolicy` lists.
3. Check the setting with `Get-OwaMailboxPolicy | Format-List Identity, IsDefault, PersonalAccountsEnabled, PersonalAccountCalendarsEnabled`.

#### Related links

* [Set-OwaMailboxPolicy](https://learn.microsoft.com/powershell/module/exchange/set-owamailboxpolicy)
* [Outlook on the web mailbox policies](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/outlook-on-the-web/outlook-web-app-mailbox-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.3.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

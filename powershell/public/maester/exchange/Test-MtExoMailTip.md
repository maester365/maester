MailTips SHOULD be enabled for end users

Rationale: MailTips assist end users with identifying strange patterns in emails they send, helping prevent accidental data leakage and improving overall email security awareness.

#### Remediation action:

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Enable MailTips for external recipients:
```powershell
Set-OrganizationConfig -MailTipsExternalRecipientsTipsEnabled $true
```

3. Verify the setting:
```powershell
(Get-OrganizationConfig).MailTipsExternalRecipientsTipsEnabled
```
The result should be `True`.

#### Related links

* [MailTips in Exchange Online](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/mailtips/mailtips)
* [Microsoft Secure Score - Enable MailTips](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%
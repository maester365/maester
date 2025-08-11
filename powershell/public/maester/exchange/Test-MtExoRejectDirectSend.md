Direct Send SHOULD be configured to `Reject` in Exchange Online

Rationale: Attackers can exploit direct send to send spam or phishing emails without authentication. Direct Send covers anonymous messages (unauthenticated messages) sent from your own domain to your organization's mailboxes using the tenant MX.

#### Remediation action:

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Configure the setting to reject direct send:
```powershell
Set-OrganizationConfig -RejectDirectSend $true
```

3. Verify the policy:
```powershell
(Get-OrganizationConfig).RejectDirectSend
```
The result should be `True`.

#### Related links

* [Introducing more control over Direct Send in Exchange Online](https://techcommunity.microsoft.com/blog/exchange/introducing-more-control-over-direct-send-in-exchange-online/4408790)
* [Direct Send: Send mail directly from your device or application to Microsoft 365](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365#direct-send-send-mail-directly-from-your-device-or-application-to-microsoft-365-or-office-365)

<!--- Results --->
%TestResult%
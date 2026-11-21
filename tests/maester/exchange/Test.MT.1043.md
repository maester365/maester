Spam confidence level (SCL) SHOULD NOT be set to -1 in mail transport rules with specific domains

Rationale: Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can enable an attacker to launch attacks against your users from a safe haven domain.

#### Remediation action

1. Connect to Exchange Online:

```powershell
Connect-ExchangeOnline
```

1. View your current transport rules:

```powershell
Get-TransportRule | Select-Object Name, SetScl
```

1. For each transport rule that uses `SetScl -1`, modify it to set SCL to 0 or higher:

```powershell
Set-TransportRule -Identity "RuleName" -SetSCL 0
```

1. Verify the changes:

```powershell
Get-TransportRule | Where-Object { $_.SetScl -eq -1 }
```

The result should return no rules.

#### Related links

* [Exchange Transport Rules and SCL values](https://learn.microsoft.com/exchange/security-and-compliance/mail-flow-rules/mail-flow-rules)
* [Spam Confidence Levels (SCL) in Exchange Online](https://learn.microsoft.com/microsoft-365/security/office-365-security/anti-spam-message-headers)
* [Microsoft Secure Score - Set SCL to 0 or higher for domains](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%

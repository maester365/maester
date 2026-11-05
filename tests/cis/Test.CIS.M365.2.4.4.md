Zero-hour auto purge (ZAP) for Microsoft Teams is turned on.

ZAP retroactively detects and blocks malware and high confidence phishing in Teams chats and channels. A message can be harmless when it's delivered and weaponized later, or a new signature can identify it after delivery. ZAP blocks such a message for everyone in the chat up to 48 hours after delivery. As with any anti-malware or anti-phishing protection, false positives can occur.

The test passes when every Teams protection policy has ZAP turned on, and fails when no policy is returned. It also lists the participants excluded from Teams protection, which CIS asks you to review. The test runs on tenants with Microsoft Defender for Office 365 Plan 2.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **System** > **Settings** > **Email & collaboration** > [**Microsoft Teams protection**](https://security.microsoft.com/securitysettings/teamsProtectionPolicy).
3. Set **Zero-hour auto purge (ZAP)** to **On (Default)**.
4. Under **Exclude these participants**, review the exclusions and remove any that are not justified.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following command:

```powershell
Set-TeamsProtectionPolicy -Identity "Teams Protection Policy" -ZapEnabled $true
```

3. Review the exclusions with `Get-TeamsProtectionPolicyRule | Format-List ExceptIf*`.

#### Related links

* [Microsoft Defender portal - Microsoft Teams protection](https://security.microsoft.com/securitysettings/teamsProtectionPolicy)
* [Zero-hour auto purge (ZAP) in Microsoft Teams](https://learn.microsoft.com/defender-office-365/zero-hour-auto-purge#zero-hour-auto-purge-zap-in-microsoft-teams)
* [Configure ZAP for Teams protection in Defender for Office 365](https://learn.microsoft.com/defender-office-365/mdo-support-teams-about#configure-zap-for-teams-protection-in-defender-for-office-365-plan-2)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.4.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

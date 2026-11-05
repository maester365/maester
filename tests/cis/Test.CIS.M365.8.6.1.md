Users can report security concerns in Microsoft Teams, and reported items go only to the organization's reporting mailbox.

User reporting lets people flag suspicious Teams messages quickly, so the security team can act on phishing and malicious content. Reported items can contain sensitive or personal information, and reports can include messages that are threatening or harassing, so they should stay inside the organization and be reviewed by staff who can route them to the right team, such as Human Resources. Sending reports to Microsoft should follow company policy.

CIS requires three settings: **Report a security concern** in the Teams Global messaging policy, **Monitor reported items in Microsoft Teams** in the Microsoft Defender portal, and reported items sent to **My reporting mailbox only**. The test reads `Get-CsTeamsMessagingPolicy -Identity Global`, the report submission policy and the report submission rule. Reporting must be on, Teams and email reports must go to the reporting mailbox and not to Microsoft (`ReportChatMessageEnabled` and `EnableReportToMicrosoft` are `False`), and the reporting mailbox must be set in the policy and in an enabled report submission rule. Microsoft Defender for Office 365 Plan 1 or Plan 2, or Microsoft Defender XDR, licences are required.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Messaging**.
3. Set **Report a security concern** to **On** and select **Save**.
4. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
5. Go to **System** > **Settings** > **Email & collaboration** > [**Teams user reported settings**](https://security.microsoft.com/securitysettings/teamsUserSubmission).
6. Under **Microsoft Teams**, select **Monitor reported items in Microsoft Teams**, set **Send reported items to** to **My reporting mailbox only**, add the reporting mailbox for authorized staff and select **Save**.
7. Go to [**User reported settings**](https://security.microsoft.com/securitysettings/userSubmission), set **Send reported items to** to **My reporting mailbox only** with the same reporting mailbox and select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams` and to Exchange Online PowerShell using `Connect-ExchangeOnline`.
2. Run the following command:

```powershell
Set-CsTeamsMessagingPolicy -Identity Global -AllowSecurityEndUserReporting $true
```

3. Change the reporting mailbox in the following script and run it:

```powershell
$usersub = "userreportedmessages@fabrikam.com" # Change this.
$params = @{
    Identity = "DefaultReportSubmissionPolicy"
    EnableReportToMicrosoft = $false
    ReportChatMessageEnabled = $false
    ReportChatMessageToCustomizedAddressEnabled = $true
    ReportChatMessageAddresses = $usersub
    ReportJunkToCustomizedAddress = $true
    ReportNotJunkToCustomizedAddress = $true
    ReportPhishToCustomizedAddress = $true
    ReportJunkAddresses = $usersub
    ReportNotJunkAddresses = $usersub
    ReportPhishAddresses = $usersub
}
Set-ReportSubmissionPolicy @params
New-ReportSubmissionRule -Name DefaultReportSubmissionRule -ReportSubmissionPolicy DefaultReportSubmissionPolicy -SentTo $usersub
```

If the report submission rule already exists, use `Set-ReportSubmissionRule -Identity DefaultReportSubmissionRule -SentTo $usersub` to configure its recipient. If the rule is disabled, enable it with `Enable-ReportSubmissionRule -Identity DefaultReportSubmissionRule`.

#### Related links

* [Microsoft Teams admin center - Settings & policies](https://admin.teams.microsoft.com/one-policy/settings)
* [Microsoft Defender portal - Teams user reported settings](https://security.microsoft.com/securitysettings/teamsUserSubmission)
* [User reported settings in Teams](https://learn.microsoft.com/defender-office-365/submissions-teams)
* [Configure user reported message settings](https://learn.microsoft.com/defender-office-365/submissions-user-reported-messages-custom-mailbox)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.6.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

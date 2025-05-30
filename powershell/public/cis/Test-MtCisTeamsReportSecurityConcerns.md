8.6.1 (L1) Ensure users can report security concerns in Teams

User reporting settings allow a user to report a message as malicious for further analysis. This recommendation is composed of 3 different settings and all be configured  to pass:
* In the Teams admin center: On by default and controls whether users are able to report messages from Teams. When this setting is turned off, users can't report messages within Teams, so the corresponding setting in the Microsoft 365 Defender portal is irrelevant.
* In the Microsoft 365 Defender portal: On by default for new tenants. Existing tenants need to enable it. If user reporting of messages is turned on in the Teams admin center, it also needs to be turned on the Defender portal for user reported messages to show up correctly on the User reported tab on the Submissions page.
* Defender - Report message destinations: This applies to more than just Microsoft Teams and allows for an organization to keep their reports contained. Due to how the parameters are configured on the backend it is included in this assessment as a requirement.

Rationale:\
Users will be able to more quickly and systematically alert administrators of suspicious malicious messages within Teams. The content of these messages may be sensitive in nature and therefore should be kept within the organization and not shared with Microsoft without first consulting company policy.

Note:\
- The reported message remains visible to the user in the Teams client.
- Users can report the same message multiple times.
- The message sender isn't notified that messages were reported.


#### Remediation action:

To change report security concerns settings using the UI:
1. Navigate to [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Click to expand **Messaging** select **Messaging policies**.
3. Click **Global (Org-wide default)**.
4. Set **Report a security concern** to **On**.
5. Next, navigate to [Microsoft 365 Defender](https://security.microsoft.com/)
6. Click on **Settings** > **Email & collaboration** > **User reported settings**.
7. Scroll to **Microsoft Teams**.
8. Check **Monitor reported messages in Microsoft Teams** and **Save**.
9. Set **Send reported messages to:** to **My reporting mailbox only** with reports configured to be sent to authorized staff.

To change who can bypass the lobby using PowerShell:
1. Connect to Teams using **Connect-MicrosoftTeams**.
2. Connecto to ExchangeOnline using **Connect-ExchangeOnline**.
3. To configure the Teams reporting policy run the following PowerShell command:
```
Set-CsTeamsMessagingPolicy -Identity Global -AllowSecurityEndUserReporting $true
```
4. To configure the Defender reporting policy, edit and run following commands:
```
$socmail = "soc@contoso.com" # Change this.
$params = @{
    Identity = "DefaultReportSubmissionPolicy"
    EnableReportToMicrosoft = $false
    ReportChatMessageEnabled = $false
    ReportChatMessageToCustomizedAddressEnabled = $true
    ReportJunkToCustomizedAddress = $true
    ReportNotJunkToCustomizedAddress = $true
    ReportPhishToCustomizedAddress = $true
    ReportJunkAddresses = $socmail
    ReportNotJunkAddresses = $socmail
    ReportPhishAddresses = $socmail
}
Set-ReportSubmissionPolicy @params
New-ReportSubmissionRule -Name DefaultReportSubmissionRule -ReportSubmissionPolicy DefaultReportSubmissionPolicy -SentTo $socmail
```


#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 420](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
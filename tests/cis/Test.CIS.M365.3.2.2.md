At least one data loss prevention policy includes the Microsoft Teams location and is turned on.

Chat and channel messages are a quick way to paste a customer list or credentials, and files that users share in Teams end up in SharePoint and OneDrive. A DLP policy that covers Teams can block or warn about sensitive information in chat messages and channel conversations, in addition to the files.

The policy must be in the **Enable** mode. DLP for Teams chat and channel messages needs Microsoft 365 E5 or the Microsoft Purview suite licence.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies) and edit a policy, or create a new one.
3. Under **Locations**, turn on **Teams chat and channel messages** and apply it to all accounts.
4. Set the policy mode to **Turn it on right away** and save the policy.

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [Data loss prevention and Microsoft Teams](https://learn.microsoft.com/purview/dlp-microsoft-teams)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

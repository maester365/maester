At least one data loss prevention (DLP) policy for Exchange, SharePoint, OneDrive or Teams is enabled. A Copilot-only policy does not satisfy this requirement.

Without DLP, sensitive information such as card numbers, national identifiers and health records can be emailed, shared or uploaded with nothing to stop it, warn the user or record it. A DLP policy gives you that control and an audit trail, even if you only start in a mode that reports. The locations it covers are the repositories and cloud storage that an attacker collects data from (T1213 and T1530), and it detects and blocks sensitive content that is sent out through a web service (T1567).

The test passes when at least one policy is in **Enable** mode and defines an **ExchangeLocation**, **SharePointLocation**, **OneDriveLocation**, or **TeamsLocation**. A policy can also cover Copilot, but must define at least one of these four workload locations to qualify. The test does not assess whether the selected rules meet the organization's DLP needs, which users are covered, or whether exclusions are permitted; review those separately. A Microsoft 365 licence that includes Purview DLP is required; tenants without it are skipped.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies) and select **Create policy**.
3. Choose a template or a custom policy and give it a name.
4. Select at least one of **Exchange email**, **SharePoint sites**, **OneDrive accounts**, or **Teams chat and channel messages**, and select the users that need protection.
5. Configure the rules for the sensitive information that matters to the organization, such as credit card numbers and personally identifiable information.
6. Set the policy mode to **Turn it on right away**, review the settings, and submit the policy. Verify that its mode is **On** in the portal (**Enable** in PowerShell).

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [Learn about data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

At least one data loss prevention (DLP) policy is turned on and applies to all users in Exchange, SharePoint, OneDrive or Teams.

Without DLP, sensitive information such as card numbers, national identifiers and health records can be emailed, shared or uploaded with nothing to stop it, warn the user or record it. A DLP policy gives you that control and an audit trail, even if you only start in a mode that reports. The locations it covers are the repositories and cloud storage that an attacker collects data from (T1213 and T1530), and it detects and blocks sensitive content that is sent out through a web service (T1567).

The test passes when one policy is in the **Enable** mode (not test mode, not off) and covers all of at least one location. Policies for Copilot are checked in a separate test. Licensing depends on the workload, and most DLP features need Microsoft 365 E3 or E5.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies) and select **Create policy**.
3. Choose a template or a custom policy, give it a name and apply it to **All** accounts for the Exchange, SharePoint, OneDrive and Teams locations.
4. Configure the rules for the sensitive information that matters to you and set the policy mode to **Turn it on right away**.

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [Learn about data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

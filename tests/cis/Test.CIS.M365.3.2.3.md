A data loss prevention policy for the Microsoft 365 Copilot location is turned on and applies to all users.

Microsoft 365 Copilot can read and summarise everything that a user can open. Without a DLP policy for the Copilot location, a prompt can bring sensitive content into an answer, or send it to a web search, and nothing in the policy limits that. A policy lets you keep content with certain sensitivity labels or sensitive information types out of Copilot responses and processing.

The policy needs to be in the **Enable** mode and to apply to all users. Copilot DLP needs Microsoft 365 Copilot licences and the Microsoft Purview licences for DLP.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies) and select **Create policy**.
3. Choose the **Custom** category and the **Custom policy** template, and under **Locations** turn on **Microsoft 365 Copilot and Copilot Chat** for all users.
4. Add a rule that blocks Copilot from processing content that has the sensitivity labels or the sensitive information types that you want to protect.
5. Set the policy mode to **Turn it on right away** and save the policy.

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Learn about the Microsoft 365 Copilot data loss prevention policy location](https://learn.microsoft.com/purview/dlp-microsoft365-copilot-location-learn-about)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

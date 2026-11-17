A data loss prevention policy for the Microsoft 365 Copilot location is turned on, includes all users, and has an enforcing rule for sensitive data.

Microsoft 365 Copilot can read and summarise everything that a user can open. Without a DLP policy for the Copilot location, a prompt can bring sensitive content into an answer, or send it to a web search, and nothing in the policy limits that. A policy lets you keep content with certain sensitivity labels or sensitive information types out of Copilot responses and processing. Copilot reads SharePoint sites and OneDrive files, so a policy on that location limits what an attacker who gets a session can collect through Copilot from them (T1213.002 and T1530).

The test requires an enabled, non-simulation Copilot policy for all users, without an administrative-unit scope, with an active **Enforce** rule that detects sensitive information types or sensitivity labels and uses a restrictive action. PowerShell represents both types of **Content contains** conditions through **ContentContainsSensitiveInformation**, including label groups, or through **AdvancedRule**. If the only otherwise qualifying policies have location exclusions or an unknown inclusion scope, the result is marked for investigation. The report lists the excluded locations so an administrator can confirm that each exception is permitted by the organization. Maester cannot determine that approval, or whether the selected data meets the organization's needs, from the policy configuration alone.

Copilot DLP needs Microsoft 365 Copilot licences and the Microsoft Purview licences for DLP.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies). Edit a suitable existing policy or select **Create policy**. The guided **Default DLP policy - Protect sensitive M365 Copilot interactions** policy can also be used if it meets the criteria above.
3. For a new custom policy, select **Enterprise applications & devices**, then **Custom** > **Custom policy**, and give it a name.
4. Under **Locations**, turn on **Microsoft 365 Copilot and Copilot Chat** for **All accounts**. Retain only location exclusions permitted by the organization.
5. Under **Advanced DLP rules**, select **Create rule**, name the rule, and add **Content contains** > **Sensitive info types**. Select the sensitive information types the organization needs to protect, such as credit card numbers and personally identifiable information.
6. Add **Restrict Copilot from processing content**, select the relevant restriction, and save the rule. Repeat for other required rules. To protect labeled files or emails, use a separate rule with **Content contains** > **Sensitivity labels** and the corresponding restriction; do not combine labels and sensitive information types in one rule.
7. Set the policy mode to **Turn it on right away**, review the settings, and submit the policy. Compliance requires enforcement mode, not simulation.

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Learn about the Microsoft 365 Copilot data loss prevention policy location](https://learn.microsoft.com/purview/dlp-microsoft365-copilot-location-learn-about)
* [New-DlpComplianceRule - ContentContainsSensitiveInformation](https://learn.microsoft.com/powershell/module/exchangepowershell/new-dlpcompliancerule#-contentcontainssensitiveinformation)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

At least one data loss prevention policy includes the Microsoft Teams location and is turned on.

Chat and channel messages are a quick way to paste a customer list or credentials, and files that users share in Teams end up in SharePoint and OneDrive. A DLP policy that covers Teams can block or warn about sensitive information in chat messages and channel conversations, in addition to the files. The policy covers the Teams content that an attacker collects from (T1213), the files stored behind it in SharePoint and OneDrive (T1530), and it stops sensitive content from leaving through a web service such as a message or an upload (T1567).

The policy must be in the **Enable** mode. Once it is on, a user who posts sensitive content in a chat or channel meets a policy tip or a block. DLP for Teams chat and channel messages needs Microsoft 365 E5 or the Microsoft Purview suite licence.

The test requires the Teams workload with **TeamsLocation** including **All**, without an administrative-unit scope. CIS permits **TeamsLocationException** entries when the organization permits them. If the only otherwise qualifying policies have exceptions, Maester lists their values and marks the result for investigation: an administrator must confirm each exception is permitted. Maester cannot infer approval from the policy configuration. Separately verify that the policy's enabled rules protect the data the organization needs.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com).
2. Go to **Solutions** > **Data loss prevention** > [**Policies**](https://purview.microsoft.com/datalossprevention/policies) and edit **Default policy for Teams**. If it is absent, edit another suitable policy or create a new one.
3. For the policy's administrative-unit scope, select **Full directory**. If the existing policy's scope cannot be changed, have an unrestricted DLP administrator create a new policy with **Full directory** selected. **All accounts** within an administrative unit does not cover the full directory.
4. Under **Locations**, turn on **Teams chat and channel messages** and apply it to **All accounts**. Review any excluded accounts or groups and retain only exceptions permitted by the organization.
5. On **Customized advanced DLP rules**, turn on **Default Teams DLP policy rule** or an organization-specific rule that protects the required data, such as credit card numbers and personally identifiable information.
6. Set the policy mode to **Turn it on right away**, review the settings, and submit the policy. Verify that its mode is **On** in the portal (**Enable** in PowerShell).

#### Related links

* [Microsoft Purview portal - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [Create and deploy data loss prevention policies](https://learn.microsoft.com/purview/dlp-create-deploy-policy)
* [Data loss prevention and Microsoft Teams](https://learn.microsoft.com/purview/dlp-microsoft-teams)
* [DLP policy reference - Administrative units](https://learn.microsoft.com/purview/dlp-policy-reference#administrative-units)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 3.2.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

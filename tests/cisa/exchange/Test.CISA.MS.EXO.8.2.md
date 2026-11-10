The DLP solution SHALL protect personally identifiable information (PII) and sensitive information, as defined by the agency.

> Reference your organization's policy defining PII.

Rationale: Users may inadvertently share sensitive information with others who should not have access to it. Data loss prevention policies provide a way for agencies to detect and prevent unauthorized disclosures.

#### Remediation action:

1. Sign in to the **Microsoft Purview compliance portal**.
2. Under the **Solutions** section, select **Data loss prevention**.
3. Select [**Policies**](https://purview.microsoft.com/datalossprevention/policies) from the left menu.
4. Select **Create policy**.
5. From the **Categories** list, select **Custom**.
6. From the **Templates** list, select **Custom policy** and then click **Next**.
7. Edit the name and description of the policy if desired, then click **Next**.
8. Under **Choose locations to apply the policy**, set **Status** to **On** for at least the Exchange email, OneDrive accounts, SharePoint sites, Teams chat and channel messages, and Devices locations, then click **Next**.
9. Under **Define policy settings**, select **Create or customize advanced DLP rules**, and then click **Next**.
10. Click **Create rule**. Assign the rule an appropriate name and description.
11. Click **Add condition**, then **Content contains**.
12. Click **Add**, then **Sensitive info types**.
13. Add information types that protect information sensitive to the agency.

    At a minimum, the agency should protect:
    - Credit card numbers
    - U.S. Individual Taxpayer Identification Numbers (ITIN)
    - U.S. Social Security Numbers (SSN)
    - All agency-defined PII and sensitive information

14. Click **Add**.
15. Under **Actions**, click **Add an action**.
16. Check **Restrict Access or encrypt the content in Microsoft 365 locations**.
17. Under this action, select **Block Everyone**.
18. Under **User notifications**, turn on **Use notifications to inform your users and help educate them on the proper use of sensitive info**.
19. Under **Microsoft 365 services**, a section that appears after user notifications are turned on, check the box next to **Notify users in Office 365 service with a policy tip**.
20. Click **Save**, then **Next**.
21. Select **Turn it on right away**, then click **Next**.
22. Click **Submit**.

#### Related links

* [Purview admin center - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [CISA 8 Data Loss Prevention Solutions - MS.EXO.8.2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo82v2)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L438)

<!--- Results --->
%TestResult%
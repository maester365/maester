Eligible and Active highly privileged role assignments SHALL trigger an alert.

Rationale: Closely monitor assignment of the highest privileged roles for signs of compromise. Send assignment alerts to enable the security monitoring team to detect compromise attempts.

#### Remediation action:

1. In **Entra admin center** select **Identity governance** and **Privileged Identity Management**.
2. Under **Manage**, select **Microsoft Entra roles**.
3. Under **Manage**, select **[Roles](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)**.

    Perform the steps below for each highly privileged role. We reference the Global Administrator role as an example.

4. Click the **Global Administrator** role.
5. Click **Settings** and then click **Edit**.
6. Click the **Notifications** tab.
7. Under **Send notifications when members are assigned as eligible to this role**, in the **Role assignment alert** > **Additional recipients** textbox, enter the email address of the security monitoring mailbox configured to receive privileged role assignment alerts.
8. Under **Send notifications when members are assigned as active to this role**, in the **Role assignment alert** > **Additional recipients** textbox, enter the email address of the security monitoring mailbox configured to receive privileged role assignment alerts.
9. Click **Update**.
10. For each of the highly privileged roles, if they have any PIM groups actively assigned to them, then also apply the same configurations per the steps above to each PIM group's **Member** settings.

#### Related links

* [Entra admin center - Privileged Identity Management | Microsoft Entra roles](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)
* [CISA 7.7 Highly Privileged User Access - MS.AAD.7.7v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad77v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L974)

<!--- Results --->
%TestResult%

Privileged roles on the Control Plane should be managed by Privileged Identity Management (PIM) only.

This test reads the Privileged Identity Management security alert **Roles are being assigned outside of Privileged Identity Management** (`RolesAssignedOutsidePimAlert`) from Microsoft Graph and passes when the alert is not active or has no affected role assignments. Emergency access (break glass) accounts are excluded from the affected items. The alert is filtered to Control Plane roles (Enterprise Access Model tiering).

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), browse to **ID Governance** > **Privileged Identity Management** > **Microsoft Entra roles** > **Alerts**.
2. Select the **Roles are being assigned outside of Privileged Identity Management** alert and follow its mitigation steps.

#### Related links

* [Configure security alerts for Microsoft Entra roles in Privileged Identity Management - Microsoft Learn](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts)

<!--- Results --->
%TestResult%

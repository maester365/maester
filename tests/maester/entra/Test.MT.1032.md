A limited number of Global Administrators should be assigned.

This test reads the Privileged Identity Management security alert **There are too many global administrators** (`TooManyGlobalAdminsAssignedToTenantAlert`) from Microsoft Graph and passes when the alert is not active or has no affected role assignments. Emergency access (break glass) accounts are excluded from the affected items.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), browse to **ID Governance** > **Privileged Identity Management** > **Microsoft Entra roles** > **Alerts**.
2. Select the **There are too many global administrators** alert and follow its mitigation steps.

#### Related links

* [Configure security alerts for Microsoft Entra roles in Privileged Identity Management - Microsoft Learn](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts)

<!--- Results --->
%TestResult%

Stale accounts should not be assigned to privileged roles.

This test reads the Privileged Identity Management security alert **Accounts in a privileged role have not signed in during the past n days** (`StaleSignInAlert`) from Microsoft Graph and passes when the alert is not active or has no affected role assignments. Emergency access (break glass) accounts are excluded from the affected items.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), browse to **ID Governance** > **Privileged Identity Management** > **Microsoft Entra roles** > **Alerts**.
2. Select the **Accounts in a privileged role have not signed in during the past n days** alert and follow its mitigation steps.

#### Related links

* [Configure security alerts for Microsoft Entra roles in Privileged Identity Management - Microsoft Learn](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts)

<!--- Results --->
%TestResult%

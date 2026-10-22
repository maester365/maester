5.1.3.1 (L1) Ensure users cannot create security groups

This setting allows users in the organization to create new security groups and add members to these groups in the Azure portal, API, or PowerShell. These new groups also show up in the Access Panel for all other users. If the policy setting on the group allows it, other users can create requests to join these groups.

The recommended state is **Users can create security groups in Azure portals, API or PowerShell** set to **No**.

#### Rationale

Allowing end users to create security groups without oversight can lead to uncontrolled group sprawl, increasing the risk of inappropriate access to sensitive data. The default assignment of group ownership to the creator introduces a potential for privilege escalation, especially if IT teams overlook how these groups are later used to manage access.

A more malicious scenario arises when a compromised non-privileged user creates deceptively named security groups such as “Accounting” or “Break-glass”, or uses homograph techniques to mimic legitimate group names. Third-party IT teams may be particularly susceptible, as they might not be familiar with the environment or lack consistent naming conventions. An unsuspecting administrator could then mistakenly assign elevated privileges, grant access to sensitive data, or exclude these groups from Conditional Access policies, inadvertently creating a serious security gap. 

#### Impact

Restrictions may introduce some operational friction, particularly in fast-paced or decentralized environments where teams rely on self-service capabilities for collaboration and access management. 

This can increase reliance on IT teams for routine tasks, potentially causing delays. However, these impacts can be minimized through automated approval workflows and clear governance processes.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Click to expand **Entra ID** > **Groups** select **General**.
3. Set **Users can create security groups in Azure portals, API or PowerShell** to **No**.

##### PowerShell

1. Connect to Microsoft Graph using `Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"`
2. Run the following commands:
```powershell
$params = @{
    defaultUserRolePermissions = @{
        AllowedToCreateSecurityGroups = $false
    }
}
Update-MgPolicyAuthorizationPolicy -BodyParameter $params
```

#### Default Value

AllowedToCreateSecurityGroups : True

#### Related links

* [Microsoft Entra admin center - Group general settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General)
* [Configure group settings in Microsoft Entra ID](https://learn.microsoft.com/entra/fundamentals/how-to-manage-groups)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.3.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

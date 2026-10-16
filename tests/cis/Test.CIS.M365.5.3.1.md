Privileged directory roles are held through Privileged Identity Management (PIM) activation instead of permanent active assignment.

An account with a permanent privileged role is a permanent target: a stolen password or token gives immediate administrative access, at any hour, with no approval, justification or time limit. Making the role eligible means the account is an ordinary user until an admin activates the role for a few hours, with MFA and an audit trail.

The test lists every active assignment to a privileged role. Users and groups pass when the assignment type is **Activated**. Service principals pass when the assignment has an end date. Up to two Global Administrator accounts on the onmicrosoft.com domain are accepted as emergency access accounts. Microsoft Entra ID P2 or Microsoft Entra ID Governance licences are required.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Roles & admins**, or open [Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles) and select **Microsoft Entra roles**.
3. Open **Assignments** > **Active assignments** and select each permanent assignment of a privileged role.
4. Select **Update** and change the assignment to **Eligible**, then save.
5. Ask the administrators to activate their role when they need it. Keep two cloud-only emergency access accounts as the only permanent Global Administrators.

#### Related links

* [Microsoft Entra admin center - Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)
* [Assign Microsoft Entra roles in Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-add-role-to-user)
* [Best practices for Microsoft Entra roles](https://learn.microsoft.com/entra/identity/role-based-access-control/best-practices)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

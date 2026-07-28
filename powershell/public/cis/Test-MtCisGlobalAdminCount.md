1.1.3 (L1) Ensure that between two and four global admins are designated

Between two and four Global Administrators should be designated in the tenant. Ideally, these accounts will not have licenses assigned to them which supports additional controls found in this benchmark.

#### Rationale

If there is only one Global Administrator, they could perform malicious activities without being detected by another admin. Designating multiple Global Administrators eliminates this risk and ensures redundancy if the sole remaining Global Administrator leaves the organization. However, to minimize the attack surface, there should be no more than four global admins set for any tenant. A large number of global admins increases the likelihood of a successful account breach by an external attacker.

#### Impact

The potential impact associated with ensuring compliance with this requirement is dependent upon the current number of Global Administrators configured in the tenant. If there is only one Global Administrator in a tenant, an additional Global Administrator will need to be identified and configured. If there are more than four Global Administrators, a review of role requirements for current Global Administrators will be required to identify which of the users require Global Administrator access.

#### Remediation action

To correct the number of global tenant administrators:

1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Select **Users** > **Active Users**.
3. In the Search field enter the name of the user to be made a Global Administrator.
4. To create a new Global Administrator:
5. Select the user's name.
6. A window will appear to the right.
7. Select **Manage roles**.
8. Select **Admin center access**.
9. Check **Global Administrator**.
10. Click Save changes.

To remove Global Admins:

1. Select **User**.
2. Under Roles select **Manage roles**.
3. De-Select the appropriate role.
4. Click **Save changes**.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Get-MgDirectoryRole](https://learn.microsoft.com/powershell/module/microsoft.graph.identity.directorymanagement/get-mgdirectoryrole?view=graph-powershell-1.0)
* [All roles](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#all-roles)
* [5. Limit the number of Global Administrators to less than 5](https://learn.microsoft.com/entra/identity/role-based-access-control/best-practices#5-limit-the-number-of-global-administrators-to-less-than-5)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 27](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

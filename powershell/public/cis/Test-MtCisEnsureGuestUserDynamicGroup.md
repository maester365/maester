5.1.3.1 (L1) Ensure a dynamic group for guest users is created

**Rationale:**
Dynamic groups allow for an automated method to assign group membership.
Guest user accounts will be automatically added to this group and through this existing conditional access rules, access controls and other security measures will ensure that new guest accounts are restricted in the same manner as existing guest accounts.

#### Remediation action:

1. Navigate to Microsoft 365 Entra admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Click to expand **Identity** select **Groups**.
3. Click **All groups**
4. Select **New group** and assign the following values:
   - Group type: **Security**
   - Microsoft Entra roles can be assigned to the group: **No**
   - Membership type: **Dynamic User**
5. Click **Add dynamic query**.
6. Click **Edit** above the Rule Syntax box.
7. Enter `(user.userType -eq "Guest")`
8. Click **OK** and **Save**.

#### Related links

* [Microsoft 365 Entra admin center | Groups](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/Overview/menuId/Overview)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 179](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
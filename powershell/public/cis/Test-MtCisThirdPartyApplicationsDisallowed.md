5.1.2.2 (L2) Ensure third party integrated applications are not allowed

**Rationale:**
Third-party integrated applications connection to services should be disabled unless there is a very clear value and robust security controls are in place.
While there are legitimate uses, attackers can grant access from breached accounts to third party applications to exfiltrate data from your tenancy without having to maintain the breached account.

#### Remediation action:

1. Navigate to Microsoft 365 Entra admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Click to expand **Entra ID** select **Users**.
3. Click **User settings**
4. Set **Users can register applications** to **No**
5. Click Save.

#### Related links

* [Microsoft 365 Entra admin Center | Users | User settings](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 167](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
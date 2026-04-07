5.1.6.2 (L1) Ensure that guest user access is restricted

**Rationale:**
By limiting guest access to the most restrictive state this helps prevent malicious group and user object enumeration in the Microsoft 365 environment. This first step, known as reconnaissance in The Cyber Kill Chain, is often conducted by attackers prior to more advanced targeted attacks.

#### Remediation action:

1. Navigate to Microsoft Entra ID admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Under **Entra ID** select **External Identities**
3. Select **External collaboration settings**
4. Under **Guest user access** set **Guest user access restrictions** to one of the following:
   - **Guest users have limited access to properties and memberships of directory objects**
   - **Guest user access is restricted to properties and memberships of their own directory objects (most restrictive)**
5. Click Save.

#### Related links

* [Microsoft 365 Entra Admin Center | External Identities | External collaboration settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings/menuId/ExternalIdentitiesGettingStarted)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 193](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
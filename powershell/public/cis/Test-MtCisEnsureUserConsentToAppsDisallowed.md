5.1.5.1 (L2) Ensure user consent to apps accessing company data on their behalf is not allowed

**Rationale:**
Attackers commonly use custom applications to trick users into granting them access to company data. Restricting user consent mitigates this risk and helps to reduce the threat-surface.

#### Remediation action:

1. Navigate to Microsoft 365 Entra admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Click to expand **Entra ID** select **Enterprise apps**.
3. Under **Security** click **Consent and permissions**
4. Under **User consent settings** select **Do not allow user consent**.
5. Click **Save**

#### Related links

* [Microsoft 365 Entra admin center | Enterprise apps | Consent and permissions | User consent settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 184](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
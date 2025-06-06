If phishing-resistant MFA has not been enforced and Microsoft Authenticator is enabled, it SHALL be configured to show login context information.

Rationale: This stopgap security policy helps protect the tenant when phishing-resistant MFA has not been enforced and Microsoft Authenticator is used. This policy helps improve the security of Microsoft Authenticator by showing user context information, which helps reduce MFA phishing compromises.

#### Remediation action:

If phishing-resistant MFA has not been deployed yet and Microsoft Authenticator is in use, configure Authenticator to display context information to users when they log in.

1. In Entra ID, click Security > Authentication methods > **Microsoft Authenticator**.
2. Click the **Configure tab**.
3. For Allow use of Microsoft Authenticator OTP select **No**.
4. Under Show application name in push and passwordless notifications select Status > **Enabled** and Target > Include > **All users**.
5. Under Show geographic location in push and passwordless notifications select Status > **Enabled** and Target > Include > **All users**.
6. Select **Save**.

#### Related links

* [CISA Strong Authentication & Secure Registration - MS.AAD.3.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad33v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L254)

<!--- Results --->
%TestResult%

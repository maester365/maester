Only administrators SHALL be allowed to consent to applications.

Rationale: Limiting applications consent to only specific privileged users reduces risk of users giving insecure applications access to their data via [consent grant attacks](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants?view=o365-worldwide).

#### Remediation action:

1. In **Entra** under **Identity** and **Applications**, select **Enterprise applications**.
2. Under **Security**, select **Consent and permissions**.
3. Under **Manage**, select **[User consent settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)**.
4. Under **User consent for applications**, select **Do not allow user consent**.
5. Click **Save**.

#### Related links

* [Entra admin center - Consent and permissions | User consent settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)
* [CISA Application Registration & Consent - MS.AAD.5.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad52v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L575)

<!--- Results --->
%TestResult%

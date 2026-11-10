**This test is deprecated by CISA as of March 2025 and will always be skipped. The content below is retained as a historical archive and will be removed in a future version.**

MS.AAD.5.4v1 was removed because Microsoft announced via MC712143 that group owner consent to applications is no longer a configurable setting. The setting has been removed from the product entirely, making the policy moot. See [CISA SCuBA Removed Policies — MS.AAD.5.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/removedpolicies.md#msaad54v1).

Group owners SHALL NOT be allowed to consent to applications.

Rationale: In M365, group owners and team owners can consent to applications accessing data in the tenant. By requiring consent requests to go through an approval workflow, risk of exposure to malicious applications is reduced.

#### Remediation action:

1. In **Entra** under **Identity** and **Applications**, select **Enterprise applications**.
2. Under **Security**, select **Consent and permissions**.
3. Under **Manage**, select **[User consent settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)**.
4. Under **Group owner consent for apps accessing data**, select **Do not allow group owner consent**.
5. Click **Save**.

#### Related links

* [Entra admin center - Consent and permissions | User consent settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings)
* [CISA Application Registration & Consent - MS.AAD.5.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad54v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L665)

<!--- Results --->
%TestResult%

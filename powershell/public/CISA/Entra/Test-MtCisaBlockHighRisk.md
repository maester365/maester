Users detected as high risk SHALL be blocked.

Rationale: Blocking high-risk users may prevent compromised accounts from accessing the tenant.

#### Remediation action:

Follow the guide below to create a conditional access policy that blocks legacy authentication.

- [Block legacy authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy#create-a-conditional-access-policy)

#### Related links

- [CISA Risk Based Policies - MS.AAD.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad21v1)
- [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L85)

<!--- Results --->
%TestResult%

Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator.

Rationale: Many privileged administrative users do not need unfettered access to the tenant to perform their duties. By assigning them to roles based on least privilege, the risks associated with having their accounts compromised are reduced.

#### Remediation action:

This policy is based on the ratio below:

`X = (Number of users assigned to the Global Administrator role) / (Number of users assigned to other highly privileged roles)`

1. Follow the instructions for policy MS.AAD.7.1v1 above to get a count of users assigned to the Global Administrator role.
2. Follow the instructions for policy MS.AAD.7.1v1 above but get a count of users assigned to the other highly privileged roles (not Global Administrator). If a user is assigned to both Global Administrator and other roles, only count that user for the Global Administrator assignment.
3. Divide the value from step 2 from the value from step 1 to calculate X. If X is less than or equal to 1 then the tenant is compliant with the policy.

#### Related links

* [CISA 7.2 Highly Privileged User Access - MS.AAD.7.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad72v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L792)

<!--- Results --->
%TestResult%

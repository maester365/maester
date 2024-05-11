Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers.

Rationale: Many privileged administrative users do not need unfettered access to the tenant to perform their duties. By assigning them to roles based on least privilege, the risks associated with having their accounts compromised are reduced.

#### Remediation action:

1. Perform the steps below for each highly privileged role. We reference the Global Administrator role as an example.
2. Create a list of all the users assigned to the **Global Administrator** role. Include users that are assigned directly to the role and users assigned via group membership. If you have Azure AD PIM, include both the **Eligible assignments** and **Active assignments**. If any of the groups assigned to Global Administrator are enrolled in PIM for Groups, also include group members from the PIM for Groups portal Eligible assignments.
3. For each highly privileged user in the list, execute the Powershell code below but replace the `username@somedomain.com` with the principal name of the user who is specific to your environment. You can get the data value from the **Principal name** field displayed in the Azure AD portal.
```
Connect-MgGraph
Get-MgBetaUser -Filter "userPrincipalName eq 'username@somedomain.com'" | FL
```
4. Review the output field named **OnPremisesImmutableId**. If this field contains a data value, it means that the user is not cloud-only. If the user is not cloud-only, create a cloud-only account for that user, assign the user to their respective roles and then remove the account that is not cloud-only from Azure AD.

#### Related links

* [CISA 7. Highly Privileged User Access - MS.AAD.7.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad73v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L833)

<!--- Results --->
%TestResult%

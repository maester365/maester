File and folder default sharing scope SHALL be set to Specific People (only the people the user specifies).

Rationale: Overly permissive default sharing settings increase the risk of unintentional data exposure. Setting the default to Specific People ensures users make deliberate sharing decisions.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Under File and folder links, set the default link type to **Specific people (only the people the user specifies)**.
4. Select Save.

#### Related links

* [CISA 2 Default Sharing Scope - MS.SHAREPOINT.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint21v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%

File and folder default sharing scope SHALL be set to Specific people (only the people the user specifies).

Rationale: Sharing files with specific people forces users to be intentional about who they are sharing information with, reducing the risk of accidental or overly broad information exposure. The default should require users to explicitly choose recipients rather than defaulting to broader sharing options.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Under **File and folder links**, set the default link type to **Specific people (only the people the user specifies)**.
4. Select **Save**.

#### Related links

* [CISA 2 Default Sharing Settings - MS.SHAREPOINT.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint21v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%
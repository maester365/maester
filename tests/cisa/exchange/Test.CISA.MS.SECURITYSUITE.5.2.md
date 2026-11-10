Audit logs SHALL be retained and searchable for a minimum of 3 months and retrievable for a minimum of 12 months.

Rationale: Audit logs may no longer be available when needed if they are not retained for a sufficient time. Searchable and retrievable logs give an agency the necessary visibility to investigate incidents that occurred in the past.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/audit).
2. Under **Solutions**, select **Audit** and confirm that audit search is available for at least the previous 3 months.
3. Open **Audit policies** and create or update retention policies for the required audit records.
4. Ensure the retention duration is at least 12 months. Creating custom retention policies may require an eligible audit license.

Maester checks the configured Exchange audit retention policy and its 12-month duration. Confirm 3-month searchability in the Audit portal.

#### Related links

* [Purview portal - Audit policies](https://purview.microsoft.com/audit/auditpolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.5.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite52v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%

Members of governed groups should come from access package assignments.

When a group is a resource in an entitlement management catalog, access to it is meant to be requested, approved, reviewed and removed through access packages. The access package drift report in **Access Guardian** compares the direct members of each governed group with the access package assignments that should grant them, and reports two kinds of drift for users and agent IDs:

* **Unauthorized access**: The group has members without a corresponding access package assignment. An owner or administrator added them directly, or the access was left behind when an assignment ended. This access skips the approval, access reviews and expiration of the access package, and an attacker who controls an account with rights to the group can use it to keep access.
* **Missing assignments**: an access package assignment is active, but the expected group membership does not exist, usually because provisioning failed.

This check fails when a governed group has unauthorized access or missing assignments. The result lists the groups with drift, sorted by unauthorized access, with the number of unauthorized and missing identities and examples of the affected users (👤), groups (👥), service principals (🧩) and agent identities (🤖). Each catalog (📚) in the **Drift in Catalog(s)** column opens the drift details of the group in that catalog. The report returns up to five drift records per resource, so **+N more** shows how many identities are not listed. Missing assignments usually mean that provisioning failed, so approved users lack the access they requested. To fail on unauthorized access only and list missing assignments for review, set the `IncludeMissingAccess` parameter to `$false`. Use `ExcludedResourceId` to leave out groups, and `MaxResources` (default 50) to limit the rows of the table. Each object in the result links to its admin portal page, and is listed on the **Affected objects** page of the report when you run `Invoke-Maester -IncludeAffectedObjects`.

The drift report lists only resources with drift, so Maester also reads the resources of your entitlement management catalogs. The check passes when governed groups exist and none has drift, and it is skipped when no group that is not role-assignable is a resource of a catalog. Role-assignable groups are left out: MT.1256 checks them.

What the report covers:

* A resource in more than one catalog is listed once, with each catalog and its own drift link; its counts are the highest of its catalogs.
* Nested group drift is not included. The report compares access package assignments only with the users directly assigned to the group.
* The report is in preview and is refreshed about once a day, so its data can be up to 24 hours old and a remediated resource keeps failing this check until the next refresh. The **Access drift data as of** timestamp on the report page shows how current the results are.

The check needs a Microsoft Entra ID Governance or Microsoft Entra Suite licence, and is skipped without it. Maester reads the report and the catalogs with the `EntitlementManagement.Read.All` permission. With delegated access, results are limited to the catalogs the signed-in user can read; the Global Administrator, Identity Governance Administrator, Directory Reader, Reports Reader, Catalog Owner and Catalog Reader roles can view the report.

Groups omitted from a batch response are checked individually. Only a confirmed HTTP 404 is treated as a deleted group. If Maester cannot read whether a governed group is role-assignable, the check reports **Error** rather than a result. Restore read access to the groups and run it again.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) and browse to **ID Governance** > **Access Guardian** > **Reports** > **Access Drift**.
2. On the **Groups** tab, sort or filter by **Unauthorized access**, and select a resource name to open its drift details, or select a catalog (📚) in the results below to open them directly.
3. For each identity with **Unauthorized access**, find out who granted the access and whether it is needed:
    * If it is needed, [assign the user to an access package](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-assignments#directly-assign-an-identity) from the drift details page. The access package picker is scoped to the resource's catalog and shows which access packages include the resource.
    * If it is not needed, select **View group** and remove the group membership.
4. For users with **Missing assignments**, [reprocess their access package assignments](https://learn.microsoft.com/entra/id-governance/entitlement-management-reprocess-access-package-assignments) from the drift details page.
5. Prevent new drift: remove group owners who grant access directly, and use access reviews on the access packages.
6. Changes apply to the resource within a few minutes, but the report, and this check, show them only after the next refresh.

#### Related links

* [View access package drift reports](https://learn.microsoft.com/entra/id-governance/entitlement-management-reports#view-access-package-drift)
* [Directly assign an identity to an access package](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-assignments#directly-assign-an-identity)
* [Reprocess access package assignments](https://learn.microsoft.com/entra/id-governance/entitlement-management-reprocess-access-package-assignments)
* [Microsoft Graph - List accessDriftSummary](https://learn.microsoft.com/graph/api/accessdriftsummary-list?view=graph-rest-beta)
* [What is entitlement management?](https://learn.microsoft.com/entra/id-governance/entitlement-management-overview)

<!--- Results --->
%TestResult%

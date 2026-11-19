Identifies GPOs whose identifiers do not appear in collected domain, OU, or site `gPLink` values. The check compares references, including disabled links; it does not determine whether a policy is actively applied. Unlinked policies may be obsolete or intentionally retained, so the result needs review rather than an assumption that each policy should be removed. Missing link or GPO collection is an error.

The result reports total, linked, and unlinked GPO counts. It lists unlinked policies only when findings exist.

#### Remediation action

1. In **Group Policy Management**, review each listed GPO's owner, purpose, backup, and change history.
2. If it is no longer needed, archive or remove it under your change process. Otherwise document why it is unlinked and retain it.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

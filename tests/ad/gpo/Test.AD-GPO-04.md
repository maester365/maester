Counts GPOs whose identifiers do not appear in the collected domain, OU, or site `gPLink` values. Unlinked policies may be obsolete, but can also be retained intentionally; verify their purpose before removing them. This check identifies references, not effective policy processing.

#### Remediation action

1. In **Group Policy Management**, review each listed GPO's owner, purpose, backup, and change history.
2. If it is no longer needed, archive or remove it under your change process. Otherwise document why it is unlinked and retain it.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

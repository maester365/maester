Checks for GPO permission reports with deny access entries. Any evaluated GPO with a deny entry is a finding and fails the test; the check does not calculate effective permissions. Unreadable descriptors are reported as unknown, not clean. All unreadable reports cause a skip, and partial unknowns without findings require investigation. Findings still fail when other reports are unknown. This check requires Windows for security-descriptor parsing; failed permission-report collection is an error.

The result summarizes GPOs with deny entries and unreadable descriptors. Details are shown only for findings or unknown reports.

#### Remediation action

1. In **Group Policy Management**, inspect listed GPOs under **Delegation** > **Advanced**.
2. Confirm each deny entry's purpose and scope. Remove an entry only after verifying it is unintended and reviewing its effect on policy recipients; document intentional restrictions. Investigate unreadable descriptors.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

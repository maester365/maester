Checks whether each evaluated GPO has an access-allowed permission entry for **Enterprise Domain Controllers**. A readable GPO without that entry is a finding and fails the test. Unreadable permissions are unknown, not missing: all unreadable reports cause a skip, and partial unknowns without findings require investigation. A finding among evaluated GPOs still fails. Failed permission-report collection is an error.

The result summarizes policies with and without the entry and those with unknown permissions. Details are shown only for findings or unknown reports.

#### Remediation action

An unknown principal assessment can also reflect conflicting allow and deny entries, even when the descriptor was read successfully. Check both descriptor access and the ACL before assuming a collection-permission problem.

Review each listed policy's intended scope and the role of Enterprise Domain Controllers. Restore the permission only if required by that design; investigate unreadable permissions rather than assuming the entry is absent.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

Checks whether each evaluated GPO has an **Authenticated Users** permission entry. A GPO without the entry is a finding and fails the test; this is a review signal, not a universal ACL requirement. Security filtering may intentionally use other groups. Unreadable permissions are unknown, not missing: all unreadable reports cause a skip, while partial unknowns without findings produce **Investigate**. Findings among evaluated GPOs still fail. Failed permission-report collection is an error.

The result summarizes GPOs with and without the entry and those with unknown permissions. Details are shown only for findings or unknown reports.

#### Remediation action

An unknown principal assessment can also reflect conflicting allow and deny entries, even when the descriptor was read successfully. Check both descriptor access and the ACL before assuming a collection-permission problem.

1. In **Group Policy Management**, inspect each listed GPO's **Scope** > **Security Filtering** and **Delegation** > **Advanced** settings.
2. Confirm intended recipients and read/apply permissions. Do not grant **Apply Group Policy** to everyone solely to clear this finding; change an ACL only when it does not match the intended policy scope. Investigate GPOs whose permissions could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

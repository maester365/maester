Checks whether each evaluated GPO has an access-allowed entry for **Domain Computers** or **Authenticated Users**. A known-present entry for either principal satisfies the check; it fails only when both are known absent. If neither is known present and one or both values are unknown, the result requires investigation. All unreadable reports cause a skip, and failed permission-report collection is an error. Principal presence is not a calculation of effective read access.

The result reports GPOs lacking Domain Computers, those lacking both principals, and those with unknown permissions. Details are shown only for findings or unknown reports.

#### Remediation action

An unknown principal assessment can also reflect conflicting allow and deny entries, even when the descriptor was read successfully. Check both descriptor access and the ACL before assuming a collection-permission problem.

Review the listed GPO's intended recipients and computer policy retrieval requirements. Confirm the required read permissions for the relevant principals before changing the ACL; a missing Domain Computers entry alone is not a finding. Investigate permissions that could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

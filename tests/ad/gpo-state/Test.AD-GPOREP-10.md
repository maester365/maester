Checks whether each collected GPO has an explicit allow entry for **Apply Group Policy**. Generic administrative grants do not count as explicit policy-application entries. A missing entry is a finding and fails the test; this does not calculate effective permissions for every user or computer. The test requires Windows for security-descriptor parsing. Missing or incomplete report collection, including unreadable permissions, is an error rather than a clean result.

The summary and metrics table report the number of GPOs without an explicit entry. A details table lists affected policies only when findings exist; otherwise, the summary says all collected GPOs have the entry.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** > **Security Filtering** and **Delegation** > **Advanced** settings.
2. Grant **Apply Group Policy** only to principals that should receive the policy. If a policy is intentionally unused, document that decision and consider archiving or removing it rather than granting access solely to clear the finding.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

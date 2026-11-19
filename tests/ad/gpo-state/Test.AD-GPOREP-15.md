Checks whether each GPO's directory version matches its SYSVOL `GPT.INI` version. A mismatch fails the test and may indicate replication or policy deployment problems. The result lists both versions for mismatched policies. Missing version data, an empty report set, or a report count that does not match the GPO inventory is an error, not a clean result.

The summary and metrics table report the version comparison. A details table lists mismatched GPOs only when any are found; otherwise, the summary says all collected versions match.

#### Remediation action

1. In **Group Policy Management**, identify each listed GPO and compare its directory and SYSVOL policy versions.
2. Diagnose replication and `GPT.INI` access, then resolve the affected policy files and directory metadata through your normal recovery process. Re-run the check after replication completes.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

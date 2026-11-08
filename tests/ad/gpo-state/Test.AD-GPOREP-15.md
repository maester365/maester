Checks whether each GPO's directory version differs from its SYSVOL GPT.INI version. A mismatch can indicate replication or policy deployment problems. The result lists both versions for mismatched policies. Incomplete SYSVOL reads or missing version fields produce an error, never a clean result.

#### Remediation action

1. In **Group Policy Management**, identify the listed GPOs and compare directory and SYSVOL policy versions.
2. Diagnose replication and GPT.INI access, then synchronize the affected policy files and directory metadata. Re-run the check after replication completes.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

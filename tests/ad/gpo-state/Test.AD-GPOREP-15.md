Checks whether each GPO's Active Directory version matches its SYSVOL `GPT.INI`
version. A mismatch fails the test and can indicate inconsistent policy state.
This is a read-only diagnostic of collected versions; it does not repair either
copy or establish the cause of a mismatch.

#### Control Type

**Detective**

#### Why This Test Matters

Group Policy stores policy information in Active Directory and SYSVOL. A version
mismatch can point to replication or policy deployment problems, leaving collected
directory and file-system state inconsistent. Clients can then receive stale or
inconsistent settings, including security controls. The result identifies the two
reported versions but does not determine which copy is authoritative.

#### Security Recommendation

Investigate each mismatch and verify replication and access to the relevant
`GPT.INI` before making changes. Use the established recovery process to restore
consistent policy state rather than manually changing a version value in isolation.

#### How the Test Works

- Compares each collected GPO's directory version with its SYSVOL `GPT.INI`
  version.
- A difference fails and is reported with both version values. Matching collected
  versions pass this comparison; they do not certify the policy's settings.
- Missing version data, an empty report set, or a report count that differs from
  the GPO inventory is an error, not a clean result.

#### Remediation action

1. In **Group Policy Management**, identify each listed GPO and verify its
   directory and SYSVOL versions, including access to `GPT.INI`.
2. Diagnose replication and collection issues, then resolve inconsistent policy
   files and directory metadata through the normal recovery process. Re-run the
   check after replication completes.

#### Related Tests

- [AD-GPO-01 — GPO inventory should be investigated](https://maester.dev/docs/tests/AD-GPO-01) (`Test-MtAdGpoTotalCount`) inventories the GPO population for context; it does not assess version consistency.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

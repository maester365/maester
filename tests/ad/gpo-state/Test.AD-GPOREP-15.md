Checks whether each GPO's directory version differs from its SYSVOL GPT.INI version. A mismatch can indicate replication or policy deployment problems. The result lists both versions for mismatched policies. Incomplete SYSVOL reads or missing version fields produce an error, never a clean result.

#### Why This Test Matters

Different directory and SYSVOL versions can make policy delivery inconsistent across domain controllers and machines. Treat the finding as replication/deployment health, not proof that a security setting was bypassed.

#### Control Type

**Detective**

#### Security Recommendation

Investigate the source of each mismatch and verify SYSVOL and directory replication before attempting to reconcile versions.

#### How the Test Works

The check compares collected directory and GPT.INI version fields per GPO, counts mismatches and displays both values. It cannot infer deployment health from an inventory count alone; missing version data is an error.

#### Related Tests

- **AD-GPO-01 — GPO inventory should be investigated** — `Test-MtAdGpoTotalCount` — Inventories GPOs separately.

#### Remediation action

1. In **Group Policy Management**, identify the listed GPOs and compare directory and SYSVOL policy versions.
2. Diagnose replication and GPT.INI access, then synchronize the affected policy files and directory metadata. Re-run the check after replication completes.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

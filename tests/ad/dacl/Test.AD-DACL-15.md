Unresolved SIDs in DACLs often indicate deleted users or groups, stale migration artifacts, or incomplete cleanup.

- **Stale delegation detection**: Old ACEs can remain after identities are removed
- **Operational hygiene**: Orphaned SID references make permissions harder to review and audit
- **Migration validation**: Unresolved SIDs can reveal accounts that were not fully remapped or retired

#### Control Type

**Operational**

#### Security Recommendation

Resolve raw SIDs against migration and translation records before deleting ACEs; an unresolved name does not prove the identity has been deleted.

#### Remediation action

- Investigate unresolved SID ACEs and determine whether they can be removed
- Validate that deprovisioning and migration processes clean up obsolete permissions
- Review privileged containers first, where stale ACEs can cause confusion during incident response

#### How the Test Works

This test reads `$adState.DaclEntries`, counts entries with an `IdentityReference` beginning `S-1-5-21`, and lists affected object DNs with distinct unresolved SID counts and SID values. A raw SID can also result from a translation failure, so confirm identities before removing ACEs. This is an inventory for investigation, not a finding that an account was deleted.

#### Related Tests

- **AD-DACL-07 — DACL identity counts and ACE distribution should be investigated** — `Test-MtAdDaclDistinctIdentityCount` — Inventories DACL identities and ACE distribution.

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

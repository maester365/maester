Conflict objects with `CNF` markers typically originate from replication or naming conflicts. Even when old, they can indicate historical AD hygiene issues and should be understood before being ignored.

- **Surfaces replication-conflict remnants** in DACL analysis
- **Helps identify cleanup candidates**
- **Provides context** for unexpected objects appearing in permission reviews

#### Control Type

**Operational**

#### Security Recommendation

Confirm the origin and current use of conflict objects before cleaning them up; a `CNF` name alone does not prove malicious activity.

#### Remediation action

Investigate conflict objects and confirm whether they are expected remnants, still referenced, or safe to clean up. Review their permissions before remediation to understand any delegated access that may still exist.

#### How the Test Works

This test retrieves `$adState.DaclEntries`, finds escaped conflict markers (`\0ACNF:`) in `ObjectDN`, and reports unique conflict objects, associated ACE counts, and each affected object's DN, class and ACE count. This is an inventory for review, not a pass/fail judgement on conflict objects.

#### Related Tests

- **AD-DACL-01 — Distinct DACL object count should be investigated** — `Test-MtAdDaclDistinctObjectCount` — Inventories distinct objects with DACL entries.
- **AD-DACL-05 — Deny ACEs and affected identities should be investigated** — `Test-MtAdDaclDenyAceCount` — Reviews deny ACEs separately.

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

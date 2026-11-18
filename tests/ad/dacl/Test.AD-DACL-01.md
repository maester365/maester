Knowing how many distinct Active Directory objects are represented in the collected DACL dataset helps establish the scope of permission analysis.

- **Measures DACL coverage** across collected directory objects
- **Provides a baseline** for comparing later DACL metrics
- **Helps validate collection breadth** when reviewing AD permission visibility

#### Control Type

**Operational**

#### Security Recommendation

Use this count as a baseline metric when reviewing DACL analysis. Unexpectedly low counts can indicate collection gaps, limited visibility, or an unexpectedly small review scope.

#### How the Test Works

This test retrieves `$adState.DaclEntries`, extracts the `ObjectDN` value from each entry, deduplicates the object list, and reports the total number of unique objects with DACL entries.

#### Related Tests

- **AD-DACL-02 — OU DACL entry count should be investigated** — `Test-MtAdDaclOuObjectCount` — Inventories OU DACL entries.
- **AD-DACL-03 — Conflict objects and their DACL entries should be investigated** — `Test-MtAdDaclConflictObjectCount` — Reviews conflict-object DACL entries.
- **AD-DACL-05 — Deny ACEs and affected identities should be investigated** — `Test-MtAdDaclDenyAceCount` — Reviews deny ACEs separately.

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

Inherited object type GUIDs define which descendant object classes an inheritable ACE targets.

- **Delegation scope visibility**: Helps show how precisely ACE inheritance is scoped
- **Privilege impact analysis**: Broad inheritance can extend powerful rights to many child objects
- **Configuration review**: Distinct inherited object types reveal the variety of object classes affected by delegations

#### Control Type

**Operational**

#### Security Recommendation

Review inherited object types against the organization's delegation model, especially where sensitive descendants receive broad access.

#### Remediation action

- Review inherited ACEs that target sensitive descendant object classes
- Prefer precise scoping over overly broad inheritance where possible
- Validate that inheritance design matches your delegation model and administrative boundaries

#### How the Test Works

This test reads `$adState.DaclEntries`, filters for nonblank `InheritedObjectType` GUIDs other than the all-zero default, and reports total ACEs, specific targeting ACEs, distinct GUIDs and the ACE and distinct object counts for each GUID. This is an inventory for review, not evidence of unsafe inheritance by itself.

#### Related Tests

- **AD-DACL-14 — Non-inherited ACE count should be investigated** — `Test-MtAdDaclNonInheritedAceCount` — Reviews non-inherited ACEs separately.
- **AD-DACL-09 — Privileged allow ACEs and affected objects should be investigated** — `Test-MtAdDaclPrivilegedAllowAceCount` — Reviews privileged allow ACEs separately.

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

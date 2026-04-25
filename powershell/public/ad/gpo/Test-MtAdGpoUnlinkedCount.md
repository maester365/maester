# Test-MtAdGpoUnlinkedCount

## Why This Test Matters

Unlinked (or orphaned) Group Policy Objects (GPOs) exist in Active Directory but are not linked to any OU, domain, or site. While they may look harmless, they can still create operational and security risk:

- **Resource and operational overhead**: Unused GPOs add clutter and can increase administrative effort.
- **Accidental exposure**: An unlinked GPO can be mistakenly linked later, suddenly applying unknown settings to users or computers.
- **Harder incident investigation**: Policy behavior becomes harder to reason about when unused GPOs remain in the environment.

## Security Recommendation

After verification, **remove unlinked GPOs** to reduce risk and simplify policy management:

- Confirm the GPO’s purpose (documentation, change history, owners).
- Verify it is not required for any special-case deployment path.
- If you are confident it is unused, remove it (or archive it) and ensure backups/restore requirements are met.
- Restrict who can create/link GPOs to prevent accidental re-introduction.

## How the Test Works

This test retrieves Active Directory Group Policy state data using `Get-MtADGpoState` and:

1. Uses the cached list of GPOs (`$gpoState.GPOs`).
2. Extracts GPO link references from the collected `GPOLinks` (via `gPLink`).
3. Counts GPOs whose IDs are not referenced by any collected `gPLink` entry.

## Related Tests

- `Test-MtAdGpoTotalCount` - Counts the total number of GPOs
- `Test-MtAdGpoLinkedCount` - Identifies GPOs that are actively linked
- `Test-MtAdGpoCreatedBefore2020Count` - Identifies potentially outdated GPOs

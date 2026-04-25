# Test-MtAdGpoLinkedCount

## Why This Test Matters

Linked Group Policy Objects (GPOs) are actively applying settings to users and/or computers across your Active Directory environment.

For security assessments, it is important to understand the scope of actively linked (and therefore applying) policies. This test helps you:

- Identify the ratio of active vs unused policies
- Spot environments where many GPOs exist but only a subset are actually applied
- Prioritize review/cleanup efforts based on real policy exposure

## Security Recommendation

- **Review linked (active) GPOs regularly**: Linked policies can change security posture immediately when modified.
- **Audit unused/unlinked GPOs**: Large numbers of unused policies can indicate mismanagement and increase the risk of accidental changes.
- **Use the linked ratio**: A low linked ratio might indicate policy sprawl or a backlog of orphaned policies.

## How the Test Works

This test retrieves GPO state from Active Directory using **Get-MtADGpoState** (it uses `$gpoState.GPOs` and `$gpoState.GPOLinks`).

It then:

1. Parses `gPLink` values to identify **enabled** (0) and **enforced** (2) link entries.
2. Counts distinct GPO GUIDs that have at least one enabled link.
3. Compares linked GPO count vs total GPO count and reports both metrics in Markdown.

## Related Tests

- `Test-MtAdGpoTotalCount` - Total GPO inventory
- `Test-MtAdGpoUnlinkedCount` - GPOs not linked anywhere
- `Test-MtAdGpoCreatedBefore2020Count` - Potentially legacy GPOs
- `Test-MtAdGpoChangedBefore2020Count` - Potentially stale GPOs

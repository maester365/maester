# Test-MtAdGpoBlockedInheritanceCount

## Why This Test Matters

GPO inheritance blocking controls whether settings from parent Organizational Units (OUs) flow down to child OUs.
When inheritance is blocked on an OU, policies from higher-level scopes won’t apply as expected.

For security assessments, this matters because inheritance blocking can create **security gaps**:

- **Parent OU policies won’t apply** to the affected OUs.
- Security baselines can become inconsistent across the directory.
- “Sticky” configurations at lower levels can persist unnoticed.

## Security Recommendation

- **Review blocked inheritance regularly**: confirm each OU blocking inheritance has a documented business/technical justification.
- **Ensure compensating controls exist**: if parent policies won’t apply, equivalent security settings must be configured directly where needed.
- **Monitor and alert on changes**: inheritance blocking is often changed unintentionally during OU restructuring or delegation work.

## How the Test Works

This test retrieves Organizational Units (OUs) from Active Directory using:

1. `Get-ADOrganizationalUnit -Filter * -Properties gpOptions`
2. Counts OUs where **`gpOptions -eq 1`** (where `gpOptions` indicates GPO inheritance blocking).
3. Reports the total OU count, the number of blocked OUs, and the blocked ratio in Markdown.

## Related Tests

- `Test-MtAdGpoEnforcedCount` - Counts enforced (inheritance-blocking) link entries
- `Test-MtAdGpoLinkedCount` - Counts GPOs actively linked to apply settings
- `Test-MtAdGpoUnlinkedCount` - Identifies unlinked/orphaned GPOs

#### Test-MtAdGroupEmptyNonPrivilegedDetails

#### Why This Test Matters

Detailed visibility into empty non-privileged groups enables effective cleanup:

- **Identification**: Lists specific groups that can be removed
- **Age assessment**: Shows creation and modification dates to determine staleness
- **Categorization**: Groups by type (security vs. distribution) and scope
- **Cleanup planning**: Provides data needed for maintenance windows
- **Audit trail**: Documents what was empty before cleanup

#### Security Recommendation

Before removing empty groups:
- Verify groups are not referenced by applications or scripts
- Check if groups are used in Group Policy or conditional access
- Document groups before deletion for potential rollback
- Consider disabling groups first before permanent deletion
- Communicate with application owners about group dependencies
- Maintain a log of cleaned groups for compliance purposes

#### How the Test Works

This test identifies all Active Directory groups that:
1. Have no members
2. Do not have adminCount = 1

It then lists these groups with their:
- Name
- Group scope (DomainLocal, Global, Universal)
- Group category (Security, Distribution)
- Creation date
- Last modification date

#### Related Tests

- `Test-MtAdGroupEmptyNonPrivilegedCount` - Counts empty non-privileged groups
- `Test-MtAdGroupPrivilegedWithMembersDetails` - Reviews privileged group memberships

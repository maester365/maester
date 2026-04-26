#### Test-MtAdGroupEmptyNonPrivilegedCount

#### Why This Test Matters

Empty groups that are not privileged (no adminCount) represent directory clutter that should be addressed:

- **Directory hygiene**: Unused groups create noise and confusion in access management
- **Audit complexity**: Empty groups increase the surface area for security audits
- **Change tracking**: Groups created for temporary purposes but never cleaned up
- **Operational efficiency**: Simplifies group management and reduces confusion
- **Potential risks**: Empty groups could be populated unexpectedly

#### Security Recommendation

Implement a regular cleanup process:
- Review empty non-privileged groups quarterly
- Establish group lifecycle policies (creation, usage, retirement)
- Document exceptions for empty groups that must be preserved
- Consider automated cleanup for groups empty for extended periods
- Maintain an exceptions list for groups required by applications

#### How the Test Works

This test iterates through all Active Directory groups, checks their membership count, and identifies groups that:
1. Have no members
2. Do not have adminCount = 1 (not privileged groups protected by AdminSDHolder)

The test categorizes groups by their status (empty privileged, empty non-privileged, with members).

#### Related Tests

- `Test-MtAdGroupEmptyNonPrivilegedDetails` - Lists specific empty non-privileged groups
- `Test-MtAdGroupPrivilegedWithMembersCount` - Reviews privileged groups with members

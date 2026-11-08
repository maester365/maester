Empty groups that are not privileged (no adminCount) represent directory clutter that should be addressed:

- **Directory hygiene**: Unused groups create noise and confusion in access management
- **Audit complexity**: Empty groups increase the surface area for security audits
- **Change tracking**: Groups created for temporary purposes but never cleaned up
- **Operational efficiency**: Simplifies group management and reduces confusion
- **Potential risks**: Empty groups could be populated unexpectedly

#### Control Type

**Operational**

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

The test categorizes collected groups by their status (empty privileged, empty non-privileged, with members). This is an opt-in (`LongRunning`) full membership scan without a first-50-groups cap. Query errors do not imply that a group is empty; the protocol connection is disposed even on failure. An empty group can still be referenced by permissions or applications, so confirm dependencies before cleanup.

#### Related Tests

- **AD-GMC-01 — Distinct groups with members count should be retrievable** — `Test-MtAdGroupMemberDistinctGroupCount` — Reports group membership inventory across all collected groups.
- **AD-GMC-10 — Privileged groups with members count should be investigated** — `Test-MtAdGroupPrivilegedWithMembersCount` — Reviews protected-group membership separately.

<!--- Results --->
%TestResult%

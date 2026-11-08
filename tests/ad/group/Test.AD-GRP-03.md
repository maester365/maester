Groups that have not been modified for longer than `MaximumAgeDays` (default 365 days) may warrant a membership and ownership review:

- **Abandoned groups**: Created for projects or purposes that no longer exist
- **Orphaned permissions**: Groups with memberships that haven't been reviewed
- **Security blind spots**: Groups that could be repurposed by attackers
- **Directory clutter**: Unused objects that complicate administration
- **Compliance issues**: Undocumented groups that auditors may question

Stale groups pose particular risks because:
- They may contain members who should have been removed
- They might grant access to resources that should be restricted
- Their purpose may be forgotten, making them difficult to audit

#### Control Type

**Detective**

#### Security Recommendation

- Establish a regular review process for groups that haven't been modified recently
- Document all groups and their purposes
- Consider implementing a group lifecycle policy with automatic expiration
- Remove groups that are no longer needed after confirming they're not referenced
- Do not make cosmetic changes merely to update the timestamp: investigate whether membership still grants appropriate access.

#### How the Test Works

This test retrieves all group objects from Active Directory and:
- Examines the modifyTimeStamp property of each group
- Fails if any group was last modified before the configurable cutoff (`MaximumAgeDays` days ago)
- Calculates the percentage of stale groups in the environment

#### Related Tests

- **AD-GRP-04 — Groups with manager count should be retrievable** — `Test-MtAdGroupWithManagerCount` — Inventories ownership metadata, not actual group usage.
- **AD-GRP-05 — Group SID History count should be retrievable** — `Test-MtAdGroupSidHistoryCount` — Reviews migration artifacts separately.

<!--- Results --->
%TestResult%

#### Test-MtAdDaclIdentityAceDistribution

#### Why This Test Matters

Knowing which identities appear most frequently in DACLs helps identify central delegation patterns, inherited administrative groups, and accounts that may have accumulated permissions over time.

- **Hotspot Detection**: Frequently occurring identities can represent broad administrative reach.
- **Permission Hygiene**: Distribution data helps distinguish expected administrative groups from unusual direct assignments.
- **Operational Review**: Repeated counts per identity make it easier to validate changes after cleanup or redesign.

#### Security Recommendation

Review identities with unusually high ACE counts. Confirm they are expected administrative groups and not stale accounts, orphaned SIDs, or overly broad delegated principals.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, groups entries by `IdentityReference`, and reports the number of ACEs associated with each identity.

#### Related Tests

- `Test-MtAdDaclDistinctIdentityCount`
- `Test-MtAdDaclPrivilegedAllowAceDetails`
- `Test-MtAdDaclPrivilegedExtendedRightDetails`

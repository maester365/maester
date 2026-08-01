#### Test-MtAdDaclUnresolvedSidCount

#### Why This Test Matters

Unresolved SIDs in DACLs often indicate deleted users or groups, stale migration artifacts, or incomplete cleanup.

- **Stale delegation detection**: Old ACEs can remain after identities are removed
- **Operational hygiene**: Orphaned SID references make permissions harder to review and audit
- **Migration validation**: Unresolved SIDs can reveal accounts that were not fully remapped or retired

#### Security Recommendation

- Investigate unresolved SID ACEs and determine whether they can be removed
- Validate that deprovisioning and migration processes clean up obsolete permissions
- Review privileged containers first, where stale ACEs can cause confusion during incident response

#### How the Test Works

This test reads `$adState.DaclEntries` and looks for entries whose `IdentityReference` starts with `S-1-5-21`, which commonly indicates a SID that did not resolve to a friendly name.

#### Related Tests

- `Test-MtAdDaclUnresolvedSidDetails` - Lists unresolved SID references by object
- `Test-MtAdDaclDistinctIdentityCount` - Counts distinct identities present in ACEs
- `Test-MtAdDaclIdentityAceDistribution` - Shows ACE distribution across identities

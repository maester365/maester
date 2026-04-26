#### Test-MtAdDaclUnresolvedSidDetails

#### Why This Test Matters

Knowing which directory objects contain orphaned SID ACEs helps target cleanup work where it matters most.

- **Object-focused remediation**: Grouping unresolved SIDs by object shows exactly where stale ACEs exist
- **Audit clarity**: Makes manual DACL review easier during privileged access assessments
- **Change tracking**: Helps confirm whether decommissioned identities still linger on important objects

#### Security Recommendation

- Remove orphaned ACEs after confirming the referenced SID is no longer valid
- Prioritize cleanup on privileged OUs, admin groups, and delegation-heavy containers
- Document recurring sources of unresolved SIDs to improve identity lifecycle processes

#### How the Test Works

This test reads `$adState.DaclEntries`, filters unresolved `IdentityReference` values that begin with `S-1-5-21`, and groups them by `ObjectDN`.

#### Related Tests

- `Test-MtAdDaclUnresolvedSidCount` - Counts unresolved SID references
- `Test-MtAdDaclNonInheritedAceCount` - Counts explicit ACEs that may require review
- `Test-MtAdDaclInheritedObjectTypeDetails` - Shows inheritance targeting across ACEs

#### Test-MtAdDaclPrivilegedExtendedRightIdentity

#### Why This Test Matters

Privileged extended rights in Active Directory can authorize sensitive operations that go beyond standard read or write permissions.

- **Privilege escalation risk**: Rights such as password reset or replication access can enable takeover paths
- **Delegation review**: Extended rights are often assigned during admin delegation and may persist longer than intended
- **Exposure visibility**: Grouping by identity shows which principals hold high-impact rights across the directory

#### Security Recommendation

- Review every identity granted privileged extended rights
- Confirm the assignment is documented, approved, and still required
- Remove stale delegations, especially for replication and password-management rights

#### How the Test Works

This test reads `$adState.DaclEntries`, filters for allow ACEs with `ActiveDirectoryRights = ExtendedRight`, matches them to a set of privileged extended right GUIDs, and groups the results by `IdentityReference`.

#### Related Tests

- `Test-MtAdDaclPrivilegedExtendedRightCount` - Counts privileged extended rights in use
- `Test-MtAdDaclPrivilegedExtendedRightDetails` - Breaks down privileged extended rights by type
- `Test-MtAdDaclNonInheritedAceCount` - Counts explicit DACL entries that may represent custom delegations

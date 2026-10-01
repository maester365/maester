#### Test-MtAdDaclDistinctIdentityCount

#### Why This Test Matters

Every DACL ACE references a security principal. Tracking the number of distinct identities appearing in delegated permissions helps you understand how widely access has been spread across the directory.

- **Delegation Visibility**: A large number of distinct identities can indicate broad or inconsistent delegation.
- **Review Prioritization**: Security teams can focus on identities that appear repeatedly across sensitive objects.
- **Baseline Tracking**: Repeated measurement makes it easier to spot growth in delegated access over time.

#### Security Recommendation

Keep delegation models simple and intentional. Prefer group-based administration over direct assignment to many individual accounts or SIDs.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, extracts unique `IdentityReference` values, and reports how many distinct identities appear across all collected ACEs.

#### Related Tests

- `Test-MtAdDaclIdentityAceDistribution`
- `Test-MtAdDaclPrivilegedAllowAceCount`
- `Test-MtAdDaclPrivilegedExtendedRightCount`

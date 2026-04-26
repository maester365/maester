#### Test-MtAdComputerSidHistoryCount

#### Why This Test Matters

SID History is an attribute used during domain migrations to maintain access to resources in the source domain. While necessary during migrations, persistent SID History on computer accounts can indicate:

- **Incomplete migrations**: Computers that were migrated but never fully transitioned
- **Security risks**: SIDs from untrusted or less-secure domains may grant unintended access
- **Directory bloat**: Unnecessary data in the directory that complicates troubleshooting
- **Audit complexity**: Makes it harder to determine effective permissions

#### Security Recommendation

- Review computers with SID History to determine if the migration is complete
- Remove SID History attributes once systems are fully migrated and resource access is verified
- Be cautious of SID History containing SIDs from external or untrusted domains
- Document any computers that legitimately require long-term SID History

#### How the Test Works

This test counts computer objects where the `SIDHistory` attribute is populated. This attribute typically contains one or more SIDs from the computer's previous domain(s).

#### Related Tests

- `Test-MtAdComputerNonStandardGroup` - Identifies other migration or configuration anomalies
- `Test-MtAdComputerDormantCount` - Finds stale accounts that may be migration remnants

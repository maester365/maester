#### Test-MtAdComputerNonStandardGroup

#### Why This Test Matters

Computer accounts should use standard primary group IDs. Non-standard primary groups may indicate:

- **Misconfiguration**: Computers accidentally assigned to incorrect groups
- **Custom security configurations**: Potential deviations from security baselines
- **Legacy issues**: Remnants of previous domain configurations or migrations
- **Privilege escalation risks**: Computers in inappropriate groups may have excessive permissions

The standard primary groups for computers are:
- **515** - Domain Computers (standard workstations and member servers)
- **516** - Domain Controllers (DC computer accounts)
- **521** - Read-only Domain Controllers (RODC computer accounts)

#### Security Recommendation

- Review computers with non-standard primary groups to understand why they deviate
- Ensure custom primary groups are intentional and properly documented
- Verify that computers are not accidentally placed in groups that grant excessive privileges
- Consider standardizing on the default groups unless there's a specific security requirement

#### How the Test Works

This test examines the `primaryGroupId` attribute of all enabled computer accounts and identifies those where the value is not 515, 516, or 521.

#### Related Tests

- `Test-MtAdComputerSidHistoryCount` - Identifies computers with migration artifacts
- `Test-MtAdComputerOUCount` - Shows the distribution of computers across OUs

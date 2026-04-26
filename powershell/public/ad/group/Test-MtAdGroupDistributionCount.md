#### Test-MtAdGroupDistributionCount

#### Why This Test Matters

Distribution groups are email-only groups used for Exchange and email distribution lists. Understanding their count and proportion helps:

- **Email infrastructure assessment**: Provides visibility into the email distribution infrastructure
- **Security boundary awareness**: Distinguishes email-only groups from security groups that control access
- **Exchange management**: Helps assess Exchange/Exchange Online integration and email distribution complexity
- **Migration planning**: Useful when planning migrations to Exchange Online or other email systems

Distribution groups cannot be used for access control—they are purely for email functionality.

#### Security Recommendation

Regularly review distribution groups to:
1. Identify and remove stale or unused distribution lists
2. Ensure sensitive distribution groups have appropriate ownership
3. Verify that distribution groups are not being used inappropriately for security purposes
4. Consider converting distribution groups to Office 365 Groups where appropriate for modern collaboration

#### How the Test Works

This test examines all group objects and identifies those where:
- The `GroupCategory` property equals "Distribution"
- These groups are used solely for email distribution, not access control

The test provides counts and percentages to understand the distribution of group types in your environment.

#### Related Tests

- `Test-MtAdGroupSecurityCount` - Counts security groups used for access control
- `Test-MtAdGroupDomainLocalCount` - Counts domain local scope groups
- `Test-MtAdGroupGlobalCount` - Counts global scope groups
- `Test-MtAdGroupUniversalCount` - Counts universal scope groups

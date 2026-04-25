# Test-MtAdGpoLinkedOUCount

## Why This Test Matters

Understanding the distribution of GPO links across Organizational Units is important for several security reasons:

- **Policy Coverage**: Identifies OUs that may lack necessary security policies
- **Compliance Assessment**: Helps ensure all organizational units receive appropriate policy coverage
- **Security Gaps**: OUs without GPO links may rely solely on domain-level policies, potentially missing OU-specific security controls
- **Policy Management**: Provides visibility into how broadly GPOs are deployed across the directory structure

## Security Recommendation

Review OUs without GPO links to ensure:

- They inherit appropriate policies from parent containers
- They don't require OU-specific security policies
- Critical security settings are not being missed
- Consider creating OU-specific policies for organizational units with unique security requirements

## How the Test Works

This test retrieves all Organizational Units from Active Directory and counts:
- Total number of OUs in the domain
- Number of OUs with GPO links (gPLink attribute is populated)
- Number of OUs without GPO links

The gPLink attribute is checked to determine if any GPOs are linked to each OU.

## Related Tests

- `Test-MtAdGpoLinkedCount` - Counts distinct GPOs with links
- `Test-MtAdGpoUnlinkedTargetCount` - Counts targets without GPO links
- `Test-MtAdComputerOUCount` - Counts distinct OUs containing computers

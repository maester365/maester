# Test-MtAdGpoDisabledLinkCount

## Why This Test Matters

Disabled GPO links represent a potential security and operational concern in Active Directory environments:

- **Policy Gaps**: Disabled links mean GPOs that are configured but not applied, potentially leaving systems without intended security controls
- **Configuration Drift**: Disabled links may indicate temporary troubleshooting that was never reverted
- **Audit Challenges**: Disabled links create confusion during security audits about which policies are actually enforced
- **Compliance Risks**: Unintentionally disabled links can result in non-compliance with security baselines

## Security Recommendation

Regularly review disabled GPO links and either:

- Re-enable links that were accidentally disabled
- Remove links that are no longer needed
- Document the justification for intentionally disabled links
- Ensure critical security policies are not inadvertently disabled

## How the Test Works

This test retrieves GPO link information from Active Directory and counts:
- Total number of GPO links
- Number of enabled links (state 0)
- Number of disabled links (state 1)
- Number of enforced links (state 2)

The gPLink attribute is parsed to determine the state of each link.

## Related Tests

- `Test-MtAdGpoEnforcedCount` - Counts enforced GPO links
- `Test-MtAdGpoLinkedCount` - Counts distinct GPOs with links
- `Test-MtAdGpoUnlinkedCount` - Identifies GPOs with no links

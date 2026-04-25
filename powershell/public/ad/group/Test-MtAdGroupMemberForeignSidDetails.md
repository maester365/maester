# Test-MtAdGroupMemberForeignSidDetails

## Why This Test Matters

Foreign security principals (FSPs) represent security principals from trusted external domains or forests. Understanding their distribution is important because:

- **Trust visibility**: Identifies external trusts that may have been forgotten or are no longer needed
- **Security boundaries**: Helps assess the blast radius if an external domain is compromised
- **Access control**: Reveals who has access to resources from outside the domain
- **Cleanup opportunities**: May highlight groups that can be cleaned up after domain migrations

## Security Recommendation

Regularly review foreign security principals:
- Remove memberships from domains that are no longer trusted
- Audit groups containing external accounts for appropriate access levels
- Document all domain trusts and their business justifications
- Consider converting external access to local accounts where appropriate
- Monitor for unexpected foreign principal additions

## How the Test Works

This test examines all group memberships in Active Directory and identifies security principals with SIDs that don't match the local domain SID. It groups these foreign principals by their domain SID and counts how many exist from each external domain.

## Related Tests

- `Test-MtAdGroupMemberForeignSidCount` - Counts total foreign security principals
- `Test-MtAdGroupPrivilegedWithMembersDetails` - Reviews privileged group memberships

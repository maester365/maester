#### Test-MtAdGroupMemberTrustCount

#### Why This Test Matters

Trust members represent security principals from external domains that have been granted access within the local domain:

- **Cross-Domain Access**: Trust members can access resources in the local domain
- **Trust Validation**: External members require the trust relationship to remain valid
- **Security Boundaries**: Understanding where external access is granted helps maintain security boundaries
- **Audit Trail**: Trust members should be regularly reviewed for continued necessity

#### Security Recommendation

Regularly audit trust members:
- Verify that trust relationships are still required and properly maintained
- Review whether external users still need access to local resources
- Document the business justification for cross-domain access
- Monitor for trust members in privileged groups (Domain Admins, etc.)

#### How the Test Works

This test identifies trust members by:
- Detecting foreignSecurityPrincipal object class
- Identifying SIDs that don't match the current domain SID pattern
- Counting unique trust members across groups

For performance reasons, the test analyzes the first 50 groups.

#### Related Tests

- `Test-MtAdGroupMemberTrustDetails` - Detailed breakdown by group
- `Test-MtAdGroupMemberForeignSidCount` - Counts foreign SIDs specifically

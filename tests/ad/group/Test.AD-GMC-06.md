Foreign SIDs represent security identifiers from domains other than the current domain:

- **SID History**: Migrated accounts may retain original SIDs for access continuity
- **Trust Relationships**: External domain SIDs indicate trust-based access
- **Cross-Forest Access**: Forest trusts may introduce SIDs from entirely different forests
- **Security Auditing**: Foreign SIDs should be tracked as they bypass some local security checks

#### Control Type

**Operational**

#### Security Recommendation

Monitor and audit foreign SIDs carefully:
- Review SID history from domain migrations for continued necessity
- Verify that trust relationships with external domains are still required
- Be cautious of foreign SIDs in highly privileged groups
- Document all foreign SID sources for compliance and security reviews

#### How the Test Works

This test analyzes group membership for foreign SIDs by:
- Comparing member SIDs against the current domain SID
- Comparing domain-account SIDs in the `S-1-5-21` namespace; well-known `S-1-5-32` and NT AUTHORITY SIDs are not foreign domains
- Grouping foreign SIDs by their domain of origin
- Counting unique foreign SID principals

The test analyzes all groups and includes group, principal, and SID details.

#### Related Tests

- `Test-MtAdGroupMemberTrustCount` - Count of trust members overall

<!--- Results --->
%TestResult%

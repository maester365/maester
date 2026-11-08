- Trust members represent security principals from external domains that have been granted access within the local domain:
- **Cross-Domain Access**: Trust members can access resources in the local domain
- **Trust Validation**: External members require the trust relationship to remain valid
- **Security Boundaries**: Understanding where external access is granted helps maintain security boundaries
- **Audit Trail**: Trust members should be regularly reviewed for continued necessity

#### Control Type

**Operational**

#### Security Recommendation

Regularly audit trust members:
- Verify that trust relationships are still required and properly maintained
- Review whether external users still need access to local resources
- Document the business justification for cross-domain access
- Monitor for trust members in privileged groups (Domain Admins, etc.)

#### How the Test Works

This test identifies trust members by:
- Detecting foreignSecurityPrincipal object class
- Identifying foreign domain-account SIDs (`S-1-5-21-…`) and foreign security principal objects; built-in `S-1-5-32` and NT AUTHORITY SIDs are not automatically foreign domains
- Counting unique trust members across groups

The test analyzes all collected groups and includes affected group names and member SIDs in its result. This complete membership scan is opt-in (`LongRunning`), not limited to 50 groups. Query failures are errors, not an empty or compliant result, and the protocol connection is disposed even on failure. Membership alone does not prove effective access to a resource.

#### Related Tests

- **AD-GMC-06 — Foreign SID principals count should be investigated** — `Test-MtAdGroupMemberForeignSidCount` — Inventories direct member objectSids outside the domain, not sIDHistory.

<!--- Results --->
%TestResult%

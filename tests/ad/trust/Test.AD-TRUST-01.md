Domain trusts are critical security boundaries in Active Directory environments. Understanding the number and configuration of trusts is essential for:

- **Security Assessment**: Knowing how many external entities can authenticate in your environment
- **Attack Surface Management**: Each trust represents a potential attack vector that needs monitoring
- **Compliance Reporting**: Many frameworks require documentation of trust relationships
- **Operational Visibility**: Understanding cross-domain authentication paths

Trusts allow users from one domain to access resources in another. While necessary for multi-domain environments, unnecessary or misconfigured trusts can create security vulnerabilities.

#### Control Type

**Operational**

#### Security Recommendation

- **Inventory**: Maintain an inventory of all trust relationships and their purposes
- **Regular Review**: Periodically review trusts to ensure they are still needed
- **Documentation**: Document the business justification for each trust
- **Monitoring**: Monitor trust validation status and authentication events
- **Principle of Least Privilege**: Only create trusts when absolutely necessary

#### How the Test Works

This test retrieves the cached LDAP trusted-domain inventory and counts the configured trusts. The test returns:

- Total count of trusts and each trust's target, direction, type, within-forest status, quarantine bit, and selective authentication bit
- Informational result (no pass/fail criteria)

#### Related Tests

- **AD-TRUST-02 — Trust inter-forest count should be investigated** — `Test-MtAdTrustInterForestCount` — Inventories inter-forest trusts.
- **AD-TRUST-03 — Applicable trusts should have strong SID filtering with no weak findings** — `Test-MtAdTrustQuarantinedCount` — Reviews SID filtering on applicable trusts.
- **AD-TRUST-06 — Trust validation age and unknown dates should be investigated** — `Test-MtAdTrustStaleCount` — Investigates trust validation age; safe LDAP cannot establish staleness.

<!--- Results --->
%TestResult%

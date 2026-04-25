# Test-MtAdDefaultQueryPolicy

## Why This Test Matters
The **default query policy** sets baseline resource constraints for LDAP operations. If defaults are overly permissive, AD can be more vulnerable to availability attacks and performance degradation from:

- Large/inefficient LDAP searches
- High-frequency query patterns
- Legitimate admin/service queries running with insufficient guardrails

Proper limits reduce the impact of both **misuse** and **mistakes**, improving DC resilience during incidents.

## Security Recommendation
- Review the default query policy and ensure it matches your organization’s acceptable performance envelope.
- Keep defaults conservative, then selectively allow exceptions only where required.
- Re-validate defaults after upgrades, migrations, or schema/config changes.

## How the Test Works
This test retrieves the default LDAP query policy values and reports them as an analyzable metric so administrators can confirm baseline limits are configured as intended.

## Related Tests
- `Test-MtAdLdapQueryPolicyCount` - Ensures query policy coverage/consistency across partitions.

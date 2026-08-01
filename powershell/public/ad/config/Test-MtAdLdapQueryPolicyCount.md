#### Test-MtAdLdapQueryPolicyCount

#### Why This Test Matters
**LDAP query policies** define resource limits for directory queries (for example, controlling maximum result sizes and query behaviors). Weak or missing limits can enable **resource exhaustion** against AD through:

- Expensive or unbounded queries
- Large searches that degrade DC performance
- Increased likelihood of availability-impacting denial-of-service (DoS)

This test helps ensure your directory query surface is bounded, making it harder for both accidental misconfigurations and malicious users to overwhelm AD.

#### Security Recommendation
- Set LDAP query policies to enforce practical limits aligned with your operational needs.
- Ensure policies are applied consistently across relevant directory contexts/partitions.
- Combine with access controls: even with good limits, ensure only authorized clients can perform heavy queries.

#### How the Test Works
This test reads LDAP query policy configuration from AD and produces a count/visibility metric indicating where query policies are present and/or set according to your expected baseline.

#### Related Tests
- `Test-MtAdDefaultQueryPolicy` - Validates the baseline LDAP query limits.

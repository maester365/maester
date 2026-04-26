#### Test-MtAdSpnMappings

#### Why This Test Matters
**SPN mappings** are used to support legacy or non-FQDN client behavior by mapping service principal names to the correct Kerberos realm/host context. While this can improve compatibility, misconfigured SPN mappings can create security and reliability issues, such as:

- **Authentication inconsistencies** (Kerberos vs. fallback behaviors)
- Clients receiving **unexpected service identity** resolution
- Increased exposure to **credential forwarding / downgrade-style** scenarios if legacy behavior is unintentionally permitted

#### Security Recommendation
- Keep SPN mappings **as minimal as possible**—only those required for supported legacy interoperability.
- Periodically review and remove stale mappings tied to retired hostnames/services.
- Validate that SPN mappings resolve to the **correct** target identities (FQDN/realm) for all required workloads.

#### How the Test Works
This test inspects the SPN mapping configuration exposed by AD, extracts the configured mappings, and provides a count/visibility metric so administrators can identify whether mappings exist that should not be present.

#### Related Tests
- `Test-MtAdWellKnownSecurityPrincipalsCount` - Identifies additional security principal surface that should be consistent with Kerberos hardening.

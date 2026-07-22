#### Test-MtAdComputerDelegationDetails

#### Why This Test Matters

Detailed visibility into Kerberos delegation configurations is essential for security because:

- **Risk prioritization**: Unconstrained delegation poses significantly higher risk than constrained delegation
- **Attack path analysis**: Understanding delegation relationships helps identify potential lateral movement paths
- **Compliance requirements**: Many security frameworks require documentation of delegation configurations
- **Incident response**: Knowing which systems have delegation helps during security investigations

Computers with unconstrained delegation should be treated as high-value targets requiring enhanced monitoring and protection.

#### Security Recommendation

For each computer with delegation enabled:

1. **Verify necessity**: Confirm the delegation is required for business operations
2. **Minimize scope**: Replace unconstrained with constrained delegation where possible
3. **Implement tiering**: Ensure tier 0 systems (Domain Controllers) never have unconstrained delegation
4. **Monitor closely**: Systems with delegation should have enhanced logging and monitoring
5. **Document exceptions**: Maintain a registry of systems requiring delegation with business justifications
6. **Regular review**: Quarterly review of delegation configurations

#### How the Test Works

This test provides a detailed breakdown of:
- Computers with unconstrained delegation (highest risk)
- Computers with constrained delegation and protocol transition
- Per-computer details including name, enabled status, and distinguished name

#### Related Tests

- `Test-MtAdComputerDelegationCount` - Provides summary counts of delegation
- `Test-MtAdComputerDormantCount` - Identifies stale accounts that may have delegation

Comprehensive trust documentation is essential for security operations:

- **Security Audits**: Auditors require detailed trust configuration information
- **Incident Response**: Understanding trust relationships helps during security incidents
- **Change Management**: Tracking trust configurations supports change control processes
- **Risk Assessment**: Detailed trust information enables proper risk evaluation
- **Compliance**: Many frameworks require documentation of trust relationships

Trust details reveal critical security properties including:
- **Direction**: Who can access whose resources
- **Type**: External vs Forest trust (different security models)
- **SID Filtering**: Whether the trust is quarantined
- **Selective Authentication**: Whether authentication is restricted

#### Control Type

**Operational**

#### Security Recommendation

**Configuration Best Practices:**

1. **Use Forest Trusts**: Prefer forest trusts over external trusts for better security
2. **Enable SID Filtering**: Always enable SID filtering on external trusts
3. **Selective Authentication**: Use selective authentication when possible
4. **Inbound Only**: Prefer inbound trusts over bidirectional when possible
5. **Document Everything**: Maintain detailed documentation of each trust's purpose

**Trust Properties to Monitor:**
- `Quarantined`: Should be `$true` for external trusts
- `SelectiveAuthentication`: Consider enabling for sensitive environments
- `Direction`: Bidirectional trusts have higher risk
- `IntraForest`: External trusts (`$false`) need extra scrutiny

#### How the Test Works

This test retrieves all trust properties from LDAP and derives display values:

- **Quarantined**: Derived from `trustAttributes` bit `0x4` (`QUARANTINED_DOMAIN`)
- **Selective Authentication**: Derived from `trustAttributes` bit `0x10` (`CROSS_ORGANIZATION`)
- **Intra-Forest**: Derived from `trustAttributes` bit `0x20` (`WITHIN_FOREST`)
- **Trust Type**: Mapped from numeric `trustType` (1=External Downlevel, 2=Domain Uplevel, 3=MIT Kerberos, 4=DCE)
- **Direction**: Mapped from numeric `trustDirection` (1=Inbound, 2=Outbound, 3=Bidirectional)

#### Related Tests

- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustInterForestCount` - External trust identification
- `Test-MtAdTrustQuarantinedCount` - SID filtering status
- `Test-MtAdTrustStaleCount` - Trust validation status

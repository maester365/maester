#### Test-MtAdTrustDetails

#### Why This Test Matters

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

This test retrieves all trust properties and displays:

- Target domain
- Trust direction
- Trust type
- Intra-forest status
- Quarantine (SID filtering) status
- Selective authentication status

#### Related Tests

- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustInterForestCount` - External trust identification
- `Test-MtAdTrustQuarantinedCount` - SID filtering status
- `Test-MtAdTrustStaleCount` - Trust validation status

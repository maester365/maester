Comprehensive trust documentation is essential for security operations:

- **Security Audits**: Auditors require detailed trust configuration information
- **Incident Response**: Understanding trust relationships helps during security incidents
- **Change Management**: Tracking trust configurations supports change control processes
- **Risk Assessment**: Detailed trust information enables proper risk evaluation
- **Compliance**: Many frameworks require documentation of trust relationships

Trust details reveal critical security properties including:
- **Direction**: Who can access whose resources
- **Type**: External vs Forest trust (different security models)
- **SID Filtering**: Whether the trust has strong SID filtering
- **Selective Authentication**: Whether authentication is restricted
- **Trust Classification**: Derived `IsForest`, `IsExternal`, and `SidFilteringWeak` properties

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
- `Quarantined`: Should be `$true` for external trusts (SID filtering enabled)
- `SidFilteringWeak`: Should be `$false` for both external and forest trusts
- `SelectiveAuthentication`: Consider enabling for sensitive environments
- `Direction`: Bidirectional trusts have higher risk
- `IsForest` / `IsExternal`: Helps identify which SID filtering rules apply

#### How the Test Works

This test retrieves all trust properties from LDAP and derives display values:

- **Quarantined**: Derived from `trustAttributes` bit `0x4` (`QUARANTINED_DOMAIN`)
- **Selective Authentication**: Derived from `trustAttributes` bit `0x10` (`CROSS_ORGANIZATION`)
- **Intra-Forest**: Derived from `trustAttributes` bit `0x20` (`WITHIN_FOREST`)
- **IsForest**: Derived from `trustAttributes` bit `0x8` (`FOREST_TRANSITIVE`)
- **IsExternal**: Derived from `trustType` in `1,2` and absence of `FOREST_TRANSITIVE` / `WITHIN_FOREST`
- **SidFilteringWeak**: External trusts weak when `QUARANTINED_DOMAIN` not set; forest trusts weak when `TREAT_AS_EXTERNAL` (`0x40`) is set
- **Trust Type**: Mapped from numeric `trustType` (1=External Downlevel, 2=Domain Uplevel, 3=MIT Kerberos, 4=DCE)
- **Direction**: Mapped from numeric `trustDirection` (1=Inbound, 2=Outbound, 3=Bidirectional)

#### Related Tests

- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustInterForestCount` - External trust identification
- `Test-MtAdTrustQuarantinedCount` - SID filtering status
- `Test-MtAdTrustStaleCount` - Trust validation status

<!--- Results --->
%TestResult%

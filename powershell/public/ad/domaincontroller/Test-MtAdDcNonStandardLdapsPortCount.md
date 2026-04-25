# Test-MtAdDcNonStandardLdapsPortCount

## Why This Test Matters

Domain controllers typically use the standard LDAPS port (636) for secure directory services communication. Non-standard LDAPS ports may indicate:

- **Custom SSL/TLS configurations** that could affect secure LDAP client connectivity
- **Security evasion attempts** where alternate ports are used to bypass network monitoring
- **Legacy or specialized deployments** with unique security requirements
- **Load balancer or proxy configurations** using different port mappings

Using non-standard LDAPS ports can cause issues with:
- Secure LDAP (LDAPS) client connectivity
- Certificate-based authentication
- Applications hardcoded to use port 636
- Network security monitoring and compliance auditing

## Security Recommendation

1. **Use standard ports where possible**: Port 636 is the industry standard for LDAPS and should be used unless there's a specific requirement
2. **Document security exceptions**: Any non-standard ports should be documented with security justification
3. **Ensure proper certificate configuration**: Non-standard LDAPS ports must have valid SSL/TLS certificates configured
4. **Audit regularly**: Review non-standard port usage during security audits to detect unauthorized changes

## How the Test Works

This test retrieves all domain controllers and checks their configured LDAPS (SSL) port. The standard LDAPS port is 636. The test reports:

- Total number of domain controllers
- Number of DCs using the standard LDAPS port (636)
- Number of DCs using non-standard LDAPS ports
- Names of DCs with non-standard ports and the specific ports they use

## Related Tests

- `Test-MtAdDcNonStandardLdapPortCount` - Checks for non-standard LDAP ports
- `Test-MtAdDcReadOnlyCount` - Analyzes RODC deployment

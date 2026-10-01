#### Test-MtAdDcNonStandardLdapPortCount

#### Why This Test Matters

Domain controllers typically use the standard LDAP port (389) for directory services communication. Non-standard LDAP ports may indicate:

- **Custom configurations** that could affect compatibility with standard LDAP clients and tools
- **Security evasion attempts** where alternate ports are used to bypass network monitoring
- **Legacy configurations** that haven't been updated to standard settings
- **Multi-tenant or specialized deployments** with unique port requirements

While non-standard ports may be intentional for specific scenarios, they can cause issues with:
- LDAP client connectivity
- Directory synchronization services
- Authentication protocols expecting standard ports
- Network security monitoring and firewall rules

#### Security Recommendation

1. **Document intentional deviations**: If non-standard ports are required, ensure they are well-documented with business justification
2. **Review firewall rules**: Ensure proper firewall rules are in place for any non-standard ports
3. **Monitor for unauthorized changes**: Non-standard ports without documentation may indicate unauthorized configuration changes
4. **Consider standardization**: Where possible, use standard ports to simplify management and troubleshooting

#### How the Test Works

This test retrieves all domain controllers and checks their configured LDAP port. The standard LDAP port is 389. The test reports:

- Total number of domain controllers
- Number of DCs using the standard LDAP port (389)
- Number of DCs using non-standard LDAP ports
- Names of DCs with non-standard ports and the specific ports they use

#### Related Tests

- `Test-MtAdDcNonStandardLdapsPortCount` - Checks for non-standard secure LDAP ports
- `Test-MtAdDcSiteCoverageCount` - Analyzes DC distribution across sites

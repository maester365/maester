#### Test-MtAdComputerSpnNonFqdnHosts

#### Why This Test Matters

SPNs should use fully qualified domain names (FQDNs) for the host portion to ensure proper Kerberos authentication across domain boundaries and to avoid ambiguity. Non-FQDN hosts can cause:

- **Authentication failures**: Kerberos may fail to find the correct service principal
- **DNS resolution issues**: Short names may not resolve correctly in all contexts
- **Cross-domain problems**: Non-FQDNs may not work across domain trusts
- **Configuration drift**: Indicates inconsistent SPN registration practices

#### Security Recommendation

Review SPNs with non-FQDN hosts:
- Determine if the SPN is still needed
- Update SPNs to use FQDN format (serviceclass/host.fqdn:port)
- Establish standards for SPN registration in your organization
- Use FQDNs consistently for all service principal names

#### How the Test Works

This test parses all computer SPNs and checks if the host portion contains a dot (indicating FQDN format). SPNs without dots in the host portion are flagged as non-FQDN.

#### Related Tests

- `Test-MtAdUserSpnNonFqdnHosts` - Checks user account SPNs for non-FQDN hosts
- `Test-MtAdComputerSpnServiceClassCount` - Overall SPN analysis

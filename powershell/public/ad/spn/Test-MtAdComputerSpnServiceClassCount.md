#### Test-MtAdComputerSpnServiceClassCount

#### Why This Test Matters

Service Principal Names (SPNs) are critical for Kerberos authentication in Active Directory. Understanding the distribution of SPN service classes helps security teams:

- **Identify service exposure**: Know what services are exposed for Kerberos authentication
- **Detect anomalies**: Unusual SPN service classes may indicate unauthorized services or misconfigurations
- **Audit service footprint**: Track the services running across your infrastructure
- **Kerberoasting assessment**: SPNs are required for Kerberoasting attacks; knowing what exists helps assess risk

Common SPN service classes include HOST, HTTP, LDAP, MSSQLSvc, and CIFS. Unexpected service classes may warrant investigation.

#### Security Recommendation

Regularly audit SPN configurations to ensure:
- Only authorized services have SPNs registered
- SPNs are registered on the correct accounts
- Unused or legacy service SPNs are removed
- Sensitive SPNs (like those for database services) are properly secured

#### How the Test Works

This test retrieves all computer objects from Active Directory, extracts their SPNs, and counts the distinct service classes. An SPN has the format `serviceclass/host:port`, and this test focuses on the service class portion.

#### Related Tests

- `Test-MtAdComputerSpnServiceClassUsage` - Shows usage breakdown of each service class
- `Test-MtAdComputerSpnUnknownCount` - Identifies unrecognized SPN service classes
- `Test-MtAdUserSpnServiceClassCount` - Counts distinct service classes on user accounts

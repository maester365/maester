#### Test-MtAdUserSpnServiceClassUsage

#### Why This Test Matters

A detailed breakdown of SPN service classes on user accounts enables:

- **Risk prioritization**: Identify high-value targets like database services
- **Service inventory**: Understand what services run under user credentials
- **Compliance assessment**: Ensure services meet security standards
- **Migration planning**: Prioritize which services to move to gMSAs first

Database and application services on user accounts pose the highest Kerberoasting risk.

#### Security Recommendation

Based on service class usage:
- Prioritize migrating database services (MSSQLSvc, oracle) to gMSAs
- Audit HTTP/HTTPS services running under user accounts
- Investigate custom or unknown service classes
- Document legitimate service accounts and their purposes

#### How the Test Works

This test analyzes all user SPNs, groups them by service class, and provides a count and percentage for each service class, helping you understand your user service account landscape.

#### Related Tests

- `Test-MtAdUserSpnServiceClassCount` - Counts distinct service classes
- `Test-MtAdUserSpnUnknownCount` - Identifies unrecognized service classes
- `Test-MtAdComputerSpnServiceClassUsage` - Computer account service class usage

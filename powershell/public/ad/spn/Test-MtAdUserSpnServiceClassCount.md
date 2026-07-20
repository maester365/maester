#### Test-MtAdUserSpnServiceClassCount

#### Why This Test Matters

Understanding the service classes of SPNs on user accounts helps security teams:

- **Identify service types**: Know what services are running under user credentials
- **Assess risk**: Some service classes (like MSSQLSvc) are higher-value targets
- **Detect anomalies**: Unexpected service classes may indicate unauthorized services
- **Plan migrations**: Identify candidates for migration to gMSAs

User accounts with database or application service SPNs are particularly sensitive.

#### Security Recommendation

Review service classes on user accounts:
- Database services (MSSQLSvc, oracle, postgres) should use gMSAs
- Web services (HTTP, HTTPS) should run under service accounts or gMSAs
- Legacy service classes may indicate outdated applications
- Document all user accounts with SPNs and their purposes

#### How the Test Works

This test retrieves all user objects with SPNs, extracts the service class from each SPN, and counts the distinct service classes in use.

#### Related Tests

- `Test-MtAdUserSpnServiceClassUsage` - Detailed breakdown of service class usage
- `Test-MtAdUserSpnTotalCount` - Total count of user SPNs
- `Test-MtAdComputerSpnServiceClassCount` - Computer account service classes

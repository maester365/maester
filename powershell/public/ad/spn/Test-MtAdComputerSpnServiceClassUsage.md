#### Test-MtAdComputerSpnServiceClassUsage

#### Why This Test Matters

Understanding the distribution of SPN service classes across your computer infrastructure provides valuable security insights:

- **Service inventory**: See what services are deployed across your environment
- **Risk assessment**: Identify high-value targets (like database services with SPNs)
- **Compliance tracking**: Ensure only approved services are configured
- **Anomaly detection**: Spot unusual service classes that may indicate shadow IT or misconfigurations

Services with SPNs are targets for Kerberoasting attacks, so knowing which services exist helps prioritize security efforts.

#### Security Recommendation

Review the service class breakdown regularly:
- Validate that all services with SPNs are authorized
- Ensure sensitive services (MSSQLSvc, etc.) have additional protections
- Remove SPNs for decommissioned services
- Consider implementing SPN attribution monitoring for critical services

#### How the Test Works

This test analyzes all computer SPNs, groups them by service class, and provides a count and percentage for each service class. This gives you a clear view of your Kerberos-authenticated service landscape.

#### Related Tests

- `Test-MtAdComputerSpnServiceClassCount` - Counts distinct service classes
- `Test-MtAdComputerSpnUnknownCount` - Identifies unrecognized service classes
- `Test-MtAdUserSpnServiceClassUsage` - Shows user account SPN service class usage

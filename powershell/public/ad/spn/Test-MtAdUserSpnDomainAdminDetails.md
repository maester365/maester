#### Test-MtAdUserSpnDomainAdminDetails

#### Why This Test Matters

Detailed visibility into domain admin SPNs is critical for security incident response:

- **Immediate remediation**: Know exactly which SPNs to remove
- **Service identification**: Understand what services were improperly configured
- **Attack surface assessment**: Evaluate the scope of exposure
- **Compliance violation**: Domain admins should never have SPNs

Any SPN on a domain admin account is a critical finding requiring immediate action.

#### Security Recommendation

**Immediate actions required:**
1. Remove ALL SPNs from domain administrator accounts
2. Investigate how and why SPNs were configured
3. Create dedicated service accounts or gMSAs for the services
4. Review domain admin membership and remove unnecessary accounts
5. Implement monitoring for SPN changes to privileged accounts
6. Consider this a potential security incident requiring investigation

#### How the Test Works

This test identifies domain administrator accounts and provides detailed information about any SPNs configured on them, including service class, host, FQDN status, and full SPN value for remediation.

#### Related Tests

- `Test-MtAdUserSpnDomainAdminCount` - Counts SPNs on domain admins
- `Test-MtAdUserSpnTotalCount` - Overall user SPN analysis
- `Test-MtAdUserSpnUnknownDetails` - Unknown SPN details on all users

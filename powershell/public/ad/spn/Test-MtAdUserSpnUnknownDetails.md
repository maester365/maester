#### Test-MtAdUserSpnUnknownDetails

#### Why This Test Matters

Detailed information about unknown user SPNs is critical for security:

- **Immediate action required**: User SPNs are prime Kerberoasting targets
- **Accountability**: Know exactly which users have unknown SPNs
- **Investigation**: Track down service owners quickly
- **Risk assessment**: Determine if high-privilege users have unknown SPNs

Unknown SPNs on privileged user accounts represent the highest risk.

#### Security Recommendation

For each unknown user SPN:
1. Contact the user or their manager to understand the service
2. Verify if the service is legitimate and necessary
3. If legitimate, document it and consider migrating to gMSA
4. If unauthorized, remove the SPN immediately
5. Check if the account has been compromised

#### How the Test Works

This test analyzes all user SPNs, identifies unknown service classes, and provides detailed information about which users have these SPNs.

#### Related Tests

- `Test-MtAdUserSpnUnknownCount` - Counts unknown service classes on users
- `Test-MtAdUserSpnDomainAdminDetails` - Checks domain admin SPNs specifically
- `Test-MtAdComputerSpnUnknownDetails` - Unknown computer SPN details

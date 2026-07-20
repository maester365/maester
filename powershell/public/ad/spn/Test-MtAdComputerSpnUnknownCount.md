#### Test-MtAdComputerSpnUnknownCount

#### Why This Test Matters

Unidentified SPN service classes can represent security risks:

- **Shadow IT**: Unknown services may be running without IT's knowledge or approval
- **Misconfigurations**: Typos or incorrect SPN registrations can cause authentication issues
- **Malicious services**: Attackers may register SPNs for rogue services
- **Legacy cleanup**: Old application SPNs may remain after decommissioning

Identifying unknown SPNs allows security teams to investigate and validate whether these services are legitimate and properly secured.

#### Security Recommendation

When unknown SPN service classes are identified:
- Investigate each unknown service class to determine its purpose
- Verify if the service is authorized and necessary
- Check if the SPN is registered on the correct account
- Remove SPNs for unauthorized or decommissioned services
- Document any custom or third-party SPNs for future reference

#### How the Test Works

This test compares discovered SPN service classes against a database of known SPNs (including standard Windows services, common enterprise applications, and database systems). Service classes not in the known list are flagged as unknown.

#### Related Tests

- `Test-MtAdComputerSpnUnknownDetails` - Provides detailed information about unknown SPNs
- `Test-MtAdComputerSpnServiceClassCount` - Counts all distinct service classes
- `Test-MtAdUserSpnUnknownCount` - Identifies unknown SPNs on user accounts

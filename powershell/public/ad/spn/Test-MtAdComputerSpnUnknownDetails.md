#### Test-MtAdComputerSpnUnknownDetails

#### Why This Test Matters

Detailed information about unknown SPNs enables security teams to:

- **Investigate effectively**: Know exactly which computers have unknown SPNs
- **Assess scope**: Understand how widespread an unknown service is
- **Track down owners**: Identify the computers to contact administrators
- **Document exceptions**: Build a list of authorized custom SPNs

This granular visibility is essential for maintaining SPN hygiene and security.

#### Security Recommendation

For each unknown SPN service class discovered:
1. Identify the service owner or application team
2. Determine if the service is legitimate and necessary
3. Verify the SPN is registered on the correct account (not a user account for a computer service)
4. Document approved custom SPNs in your security baseline
5. Remove or correct unauthorized SPNs

#### How the Test Works

This test analyzes all computer SPNs, compares service classes against a known database, and provides a detailed breakdown of unknown service classes including which computers have them and how many instances exist.

#### Related Tests

- `Test-MtAdComputerSpnUnknownCount` - Counts unknown service classes
- `Test-MtAdUserSpnUnknownDetails` - Details of unknown user account SPNs
- `Test-MtAdComputerSpnServiceClassUsage` - All service class usage breakdown

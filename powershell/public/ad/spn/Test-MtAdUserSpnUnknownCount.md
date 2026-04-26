#### Test-MtAdUserSpnUnknownCount

#### Why This Test Matters

Unknown SPN service classes on user accounts require immediate attention because:

- **High risk**: User accounts with SPNs are Kerberoasting targets
- **Shadow IT**: Unknown services may bypass security controls
- **Misconfigurations**: Could indicate improper SPN registration
- **Compliance issues**: Unauthorized services violate security policies

User accounts are preferred targets for Kerberoasting, making unknown SPNs on these accounts particularly concerning.

#### Security Recommendation

Investigate all unknown SPNs on user accounts:
- Determine the service owner and business justification
- Verify if the service requires a user account or can use gMSA
- Check for misconfigurations or typos
- Remove unauthorized SPNs immediately
- Document approved custom SPNs

#### How the Test Works

This test compares discovered user SPN service classes against a database of known SPNs and flags any unrecognized service classes for investigation.

#### Related Tests

- `Test-MtAdUserSpnUnknownDetails` - Detailed information about unknown user SPNs
- `Test-MtAdComputerSpnUnknownCount` - Unknown SPNs on computer accounts
- `Test-MtAdUserSpnServiceClassCount` - All user SPN service classes

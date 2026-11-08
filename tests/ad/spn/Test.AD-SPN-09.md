Unknown SPN service classes on user accounts require immediate attention because:

- **High risk**: User accounts with SPNs are Kerberoasting targets
- **Shadow IT**: Unknown services may bypass security controls
- **Misconfigurations**: Could indicate improper SPN registration
- **Compliance issues**: Unauthorized services violate security policies

User accounts are preferred targets for Kerberoasting, making unknown SPNs on these accounts particularly concerning.

#### Control Type

**Operational**

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

- **AD-SPN-03 — Computer SPN unknown service class count should be retrievable** — `Test-MtAdComputerSpnUnknownCount` — Reviews computer SPN classes not on the known list.
- **AD-SPN-07 — User SPN service class count should be investigated** — `Test-MtAdUserSpnServiceClassCount` — Inventories all user SPN classes.

<!--- Results --->
%TestResult%

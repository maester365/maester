#### Test-MtAdUserDelegationDetails

#### Why This Test Matters

Delegation details on user accounts help defenders quickly identify high-risk service identities and prioritize cleanup.

- **Risk prioritization**: Unconstrained delegation is usually more dangerous than protocol transition alone.
- **Account review**: User-based service accounts with SPNs and delegation need strong justification.
- **Incident response**: Detailed visibility speeds triage during suspected Kerberos abuse.

#### Security Recommendation

- Review each delegation-enabled user for business need, owner, and scope.
- Remove unnecessary delegation settings.
- Replace legacy service users with safer identity patterns where possible.
- Monitor delegation-enabled accounts for unusual logon or ticket activity.

#### How the Test Works

This test lists each user with `TrustedForDelegation` or `TrustedToAuthForDelegation` enabled and labels the effective delegation type based on the available account flags.

#### Related Tests

- `Test-MtAdUserDelegationConfiguredCount`
- `Test-MtAdUserKnownServiceAccountDetails`

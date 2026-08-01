#### Test-MtAdUserSpnSetCount

#### Why This Test Matters

User accounts with `ServicePrincipalName` values are typically used as service accounts. These accounts are important because they may be susceptible to Kerberoasting and often have broad or persistent access.

- **Kerberoasting exposure**: User SPNs are a common attack target
- **Service account discovery**: Helps inventory service identities in the domain
- **Hardening priority**: Supports review of password hygiene, delegation, and logon restrictions

#### Security Recommendation

- Review every user account with an SPN and confirm it is a legitimate service account
- Prefer managed service account options where possible
- Ensure service accounts use strong credential and monitoring controls

#### How the Test Works

This test counts user objects where the `ServicePrincipalName` attribute contains one or more values.

#### Related Tests

- `Test-MtAdUserKnownServiceAccountCount` - Identifies service accounts by naming convention
- `Test-MtAdUserAdminCountCount` - Highlights protected user accounts that may need extra scrutiny

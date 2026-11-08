User accounts with Service Principal Names (SPNs) are high-value targets for attackers because:

- **Kerberoasting**: Attackers can request service tickets for these SPNs and attempt to crack them offline
- **Service account exposure**: User accounts with SPNs often have elevated privileges
- **Password policy gaps**: Service accounts may have weaker password policies than expected
- **Shadow service accounts**: Unknown user accounts with SPNs may indicate unauthorized services

Understanding the scope of user SPNs helps assess your Kerberoasting attack surface.

#### Control Type

**Operational**

#### Security Recommendation

Minimize user accounts with SPNs:
- Use Group Managed Service Accounts (gMSAs) instead of user accounts for services
- Regularly audit user accounts with SPNs
- Ensure service accounts have strong, regularly rotated passwords
- Consider using Managed Service Accounts (MSAs) where possible
- Remove SPNs from accounts that no longer need them

#### How the Test Works

This test retrieves all user objects from Active Directory, extracts their SPNs, and counts the total number of SPNs configured on user accounts.

#### Coverage crosswalk

This check includes former AD-USER-14. The engine supports one `Feature`, so the primary classification remains `service-principal-names`; the associated `users` context is linked through AD-USER-20 (service-account patterns) and AD-SPN-12 (privileged user SPNs), not a second feature attribute.

#### Related Tests

- **AD-SPN-07 — User SPN service class count should be investigated** — `Test-MtAdUserSpnServiceClassCount` — Inventories service classes on users.
- **AD-SPN-12 — No domain admin accounts should have SPNs configured** — `Test-MtAdUserSpnDomainAdminCount` — Checks privileged user SPNs.
- **AD-SPN-01 — Computer SPN service class count should be retrievable** — `Test-MtAdComputerSpnServiceClassCount` — Inventories computer-account SPN classes.
- **AD-USER-20 — Service-like user names should be reviewed** — `Test-MtAdUserKnownServiceAccountCount` — Inventories naming patterns independently of SPNs.

<!--- Results --->
%TestResult%

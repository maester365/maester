DES is an obsolete Kerberos encryption type with known cryptographic weakness. Accounts limited to DES-only support should be considered legacy debt and prioritized for cleanup.

#### Control Type

**Detective**

#### Security Recommendation

Move DES-only accounts to stronger Kerberos encryption types such as AES and eliminate dependencies on deprecated protocols. Validate application compatibility before enforcement.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts whose Kerberos settings indicate DES usage. It checks `KerberosEncryptionType` when available and falls back to `UseDESKeyOnly`.

#### Related Tests

- `Test-MtAdUserDelegationAllowedCount`
- `Test-MtAdUserReversibleEncryptionCount`
- `Test-MtAdUserNoPreAuthCount`

#### Related links

- [Microsoft Defender for Identity: Unsecure account attributes](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-account-attributes)
- [ANSSI Active Directory checkpoints: Use of Kerberos with weak encryption](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_kerberos_properties_deskey)

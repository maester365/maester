Reversible password encryption is effectively equivalent to storing passwords in a decryptable form. Accounts configured this way create serious exposure if the directory or credential material is compromised.

#### Security Recommendation

Disable reversible password encryption unless it is required for a documented legacy dependency that cannot be modernized immediately. Remediate those dependencies as a priority.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts with reversible-encryption-style indicators. It checks explicit reversible encryption properties when available and falls back to the relevant `userAccountControl` flag.

#### Related Tests

- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNotRequiredCount`
- `Test-MtAdUserNoPreAuthCount`

#### Related links

- [Microsoft Defender for Identity: Unsecure account attributes](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-account-attributes)
- [ANSSI Active Directory checkpoints: Privileged accounts with passwords stored using reversible encryption](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_reversible_password_priv_uac)

<!--- Results --->
%TestResult%

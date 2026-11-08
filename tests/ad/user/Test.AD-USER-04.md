Reversible password encryption is effectively equivalent to storing passwords in a decryptable form. Accounts configured this way create serious exposure if the directory or credential material is compromised.

#### Control Type

**Detective**

#### Remediation action

Review legacy application dependencies, disable reversible password encryption on the affected accounts and effective policies, then reset affected passwords. Turning the flag off alone does not prove previously stored credential material was removed. Pilot changes where dependent authentication mechanisms may break.

#### How the Test Works

This check fails when an account permits reversible password encryption and lists those accounts. It reads cached account-control data and errors when that data is unavailable. The configuration flag is not proof that a current password was actually stored reversibly; default and fine-grained policy settings are assessed separately by AD-PWDPOL-01 and AD-FGPP-01.

#### Related Tests

- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNotRequiredCount`
- `Test-MtAdUserNoPreAuthCount`

#### Related links

- [Microsoft Defender for Identity: Unsecure account attributes](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-account-attributes)
- [ANSSI Active Directory checkpoints: Privileged accounts with passwords stored using reversible encryption](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_reversible_password_priv_uac)

<!--- Results --->
%TestResult%

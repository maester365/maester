- The KRBTGT account is the most critical service account in Active Directory. It is used by the Key Distribution Center (KDC) service to encrypt and sign all Kerberos tickets within the domain. If this account is compromised, an attacker can forge Kerberos tickets (Golden Tickets) that grant unlimited access to any resource in the domain.

**Security Risks:**
- **Golden Ticket Attacks**: Compromised KRBTGT password allows attackers to forge TGTs for any user
- **Persistent Access**: Attackers can maintain access even after password changes if they create forged tickets with long lifetimes
- **Domain-Wide Impact**: A single compromised KRBTGT affects the entire domain

#### Control Type

**Preventive**

#### Security Recommendation

1. **Rotate KRBTGT password regularly**:
   - At least every `MaxPasswordAgeDays` days (default 180, about twice per year)
   - Immediately if compromise is suspected

2. **If compromise is suspected**:
   - Rotate the password **twice** with at least 10 hours between rotations
   - First rotation invalidates existing forged tickets
   - Second rotation ensures any tickets created between rotations are also invalidated

3. **Monitor for anomalies**:
   - Unexpected password changes
   - Unusual authentication patterns
   - KRBTGT account being enabled (investigated separately under AD-KRBTGT-03)

#### How the Test Works

This test retrieves the KRBTGT account from Active Directory and checks:
- Password last set date
- Days since last password change
- Whether password age exceeds `MaxPasswordAgeDays` (default 180)
- Account status (reported for context; this check only evaluates password age)

If the user inventory or KRBTGT account is missing, the check produces **Error**, not a finding that the password age failed. A missing `PasswordLastSet` on a visible account does not establish a recent password change and fails the age check. Rotation during incident response requires a planned two-stage procedure; do not assume that an arbitrary ten-hour interval fits every ticket policy.

#### Related Tests

- **AD-KRBTGT-02 — KRBTGT last logon should be investigated** — `Test-MtAdKrbtgtLastLogon` — Reviews KRBTGT last logon separately.
- **AD-KRBTGT-03 — KRBTGT should have standard UAC settings (disabled account)** — `Test-MtAdKrbtgtNonStandardUacCount` — Reviews KRBTGT UAC settings.

#### Related links

- [Microsoft Defender for Identity: Change password for krbtgt account](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#change-password-for-krbtgt-account)
- [ANSSI Active Directory checkpoints: Krbtgt account password unchanged for more than a year](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_krbtgt)

<!--- Results --->
%TestResult%

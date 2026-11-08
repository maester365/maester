Evaluates the default domain password policy's length, history, expiration, complexity, reversible encryption, lockout threshold, duration and reset window; reports minimum password age for review.

This check consolidates the former history-only AD-PWDPOL-01 with AD-PWDPOL-02 through AD-PWDPOL-07. Its `CurrentNist` default expects 15 characters (assume single factor: LDAP cannot establish MFA) and no forced periodic rotation; before applying a minimum above 14 characters, verify domain controller and client support and configure **Relax minimum password length limits** where applicable. The 24 remembered passwords and 1–10 attempts/15-minute duration and reset are separate Microsoft baseline/local criteria, **not NIST requirements**. Zero lockout duration is valid administrator unlock. Complexity is observation only under `CurrentNist`: do not disable it unless the blocklist is independently verified. The configurable `LegacyRotation` profile expects 14 characters, enabled complexity and a maximum age between 1 and 90 days; it is an organization-selected legacy profile, not earlier NIST guidance. Configure thresholds with `TestSettings[].Parameters`. LDAP cannot establish blocklist coverage, MFA, actual password strength or full NIST compliance.

#### Control Type

**Operational**

#### Security Recommendation

Review the default domain password and lockout settings against the selected profile and local Microsoft baseline. Confirm blocklist coverage, MFA and actual credential strength separately; no periodic-rotation requirement is attributed to current or earlier NIST guidance.

#### How the Test Works

The test evaluates length, history, expiration, reversible encryption and lockout settings of the default policy. `CurrentNist` treats complexity and minimum age as observations and does not require forced periodic expiration; `LegacyRotation` is optional organization-selected policy. LDAP settings alone do not prove comprehensive compliance.

#### Related Tests

- **AD-FGPP-01 — Fine-grained password policies should meet configured safeguards and be in use** — `Test-MtAdFineGrainedPasswordPolicySecurity` — Assesses fine-grained settings (High) and usage (Low) separately.
- **AD-USER-03 — Enabled users should meet the selected effective password expiration policy** — `Test-MtAdUserEffectivePasswordExpiration` — Resolves effective expiration for users.

#### Remediation action

1. In **Group Policy Management**, edit the effective default domain password and account lockout policy under **Computer Configuration** > **Policies** > **Windows Settings** > **Security Settings** > **Account Policies**.
2. Correct failing settings according to your selected profile; verify password blocklisting and MFA independently and reset credentials on evidence of compromise.

#### Related links

* [NIST SP 800-63B password verifiers](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/#passwords)
* [NIST SP 800-63B Rev. 3 (also discouraged arbitrary rotation)](https://pages.nist.gov/800-63-3/sp800-63b.html#reqauthtype)
* [Microsoft account lockout policy](https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/account-lockout-policy)

<!--- Results --->
%TestResult%

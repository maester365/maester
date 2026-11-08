Checks effective password expiration for enabled users, including account-level `PasswordNeverExpires` overrides and the computed resultant fine-grained policy or default domain policy.

The default `CurrentNist` profile does **not** require periodic expiration. The optional `LegacyRotation` profile requires a positive maximum age no greater than 90 days by default and no account-level never-expire override; it is an organization-selected rotation requirement, **not earlier NIST guidance** (Rev. 3 already discouraged arbitrary changes). Set `Profile`, `MaximumAgeDays`, and `PolicyInventoryReadAccessConfirmed` in `TestSettings[].Parameters`; visibility confirmation is **operator-provided**, not automatically inferred from LDAP. A missing resultant-policy attribute, unknown DN or absent policy age is an error; an unconfirmed empty DN or empty visible user set is **Investigate**, not proof of default-policy coverage. LDAP cannot prove MFA, password blocklisting, actual credential strength or complete compliance.

#### Control Type

**Detective**

#### Security Recommendation

Choose the password-expiration profile with policy owners and verify each enabled user's effective policy before changing settings. Do not describe the optional 90-day legacy rotation profile as previous NIST guidance.

#### How the Test Works

The test resolves enabled users' resultant fine-grained policy or domain default and evaluates account overrides under `CurrentNist` (no periodic expiry) or the optional `LegacyRotation` profile (configured maximum 90 days). Missing or unreadable policy data is not a compliant result; inventory visibility must be operator-confirmed.

#### Related Tests

- **AD-FGPP-01 — Fine-grained password policies should meet configured safeguards and be in use** — `Test-MtAdFineGrainedPasswordPolicySecurity` — Reviews PSO settings and effective usage separately.
- **AD-PWDPOL-01 — Default domain password policy should meet configured safeguards** — `Test-MtAdDefaultPasswordPolicySecurity` — Reviews domain default settings.

#### Remediation action

1. In **Active Directory Administrative Center**, inspect each listed user and its **Resultant Password Settings**; inspect the domain default policy and the **Password Settings Container** for effective expiration settings.
2. Under `CurrentNist`, configure maximum password age through the effective domain policy or PSO; do not enable per-account `PasswordNeverExpires` just to satisfy this check. Those overrides are separately reported as Investigate. Under `LegacyRotation`, review policy and approved account exceptions with the owner. Independently verify password blocklisting and reset passwords when compromise is known.

#### Related links

* [NIST SP 800-63B password verifier requirements](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/#passwords)
* [NIST SP 800-63B Rev. 3](https://pages.nist.gov/800-63-3/sp800-63b.html#reqauthtype)

<!--- Results --->
%TestResult%

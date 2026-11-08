Evaluates every visible fine-grained password policy (PSO) in two separate results: security settings (**High**) and PSO existence/effective usage (**Low**).

This check replaces AD-FGPP-02 (distinct values), AD-FGPP-03 (settings) and AD-FGPP-04 (direct targets). The fixed family rows are `AD-FGPP-01.settings` (**High**, evaluates settings only) and `AD-FGPP-01.usage` (**Low**, configuration hygiene only). Direct targeting is not effective usage: the computed `ResultantPasswordPolicyDN` for visible enabled users determines which PSO wins precedence. A PSO with no users receiving it fails **only in the Low usage row** when read access is explicitly confirmed and enabled users are visible; otherwise usage is **Investigate**. An unknown resultant DN or missing attribute is an error in usage. An empty PSO inventory is **Investigate** in both rows unless complete read access is operator-confirmed; then the settings row is **NotApplicable**, and only the Low usage row fails. A failing usage result does not assert that password security settings are weak.

The default `CurrentNist` profile checks 15-character minimum (single-factor assumption; LDAP does not establish MFA), no forced periodic rotation, reversible encryption off, Microsoft password history at least 24, and configurable lockout threshold 1–10, duration 15 minutes (or zero for administrator unlock), and reset window 15 minutes. Before applying a minimum above 14 characters, verify that domain controllers and clients support the required Windows minimum-length policy configuration (including **Relax minimum password length limits** where applicable). Minimum password age and complexity are reported as observations under this profile; do not disable existing composition rules until a password blocklist has been verified. `LegacyRotation` instead defaults to 14 characters, enabled complexity and maximum age 1–90 days; this is an **organization-selected legacy profile, not a prior NIST requirement**. Thresholds can be overridden in `TestSettings[].Parameters`. `PolicyInventoryReadAccessConfirmed` is an operator confirmation, not proof inferred from LDAP or an automatic permission check. This partial LDAP assessment cannot verify the password blocklist, MFA enforcement, actual password strength, or complete NIST compliance.

#### Control Type

**Operational**

#### Security Recommendation

Review PSO safeguards independently of whether policies are used. Assess a policy's effective recipients through resultant password policy, not merely direct assignments; investigate incomplete inventory before drawing conclusions.

#### How the Test Works

Two fixed family results evaluate all visible PSOs: `AD-FGPP-01.settings` tests configured password safeguards at **High** severity; `AD-FGPP-01.usage` assesses effective usage at **Low** severity. A zero visible inventory is not evidence of no PSOs unless read access is operator-confirmed. This LDAP check cannot establish full NIST compliance.

#### Related Tests

- **AD-PWDPOL-01 — Default domain password policy should meet configured safeguards** — `Test-MtAdDefaultPasswordPolicySecurity` — Assesses the domain default separately.
- **AD-USER-03 — Enabled users should meet the selected effective password expiration policy** — `Test-MtAdUserEffectivePasswordExpiration` — Resolves effective expiration per user.

#### Remediation action

1. In **Active Directory Administrative Center**, open your domain > **System** > **Password Settings Container**.
2. Correct any settings-row failures independently of unused-policy hygiene. For usage-row findings, review direct assignments or retire an unused PSO after checking intent; inspect computed resultant policy for intended users and confirm inventory read access before interpreting absent usage. Usage cleanup is not a reason to weaken a policy.
3. Verify a compromised/common-password blocklist, MFA and compromise-triggered resets independently; do not change complexity solely on this check's observation.

#### Related links

* [NIST SP 800-63B, password verifier requirements](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/#passwords)
* [Microsoft password policy settings](https://learn.microsoft.com/windows/security/threat-protection/security-policy-settings/account-policies)

<!--- Results --->
%TestResult%

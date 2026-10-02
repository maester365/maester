Delegation-capable user accounts can impersonate users to downstream services. If these accounts are over-privileged or poorly protected, they can become valuable pivot points for privilege escalation and lateral movement.

#### Security Recommendation

Limit delegation to only the accounts that need it, prefer constrained models, and protect delegated accounts with strong authentication, tiering, and monitoring.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts where `TrustedForDelegation` or `TrustedToAuthForDelegation` is enabled. The results break out delegation types and show the overall count.

#### Related Tests

- `Test-MtAdUserNoPreAuthCount`
- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNeverExpiresCount`

#### Related links

- [Microsoft Defender for Identity: Ensure privileged accounts are not delegated](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#ensure-privileged-accounts-are-not-delegated)
- [ANSSI Active Directory checkpoints: Unconstrained authentication delegation](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_delegation_t4d)

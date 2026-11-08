Checks that `ms-DS-MachineAccountQuota` is zero in the connected domain. The default quota of 10 permits ordinary users to create computer accounts; restricting that path reduces opportunities to establish attacker-controlled domain identities.

Unauthorized joins can create rogue domain computer identities and complicate account inventory. The quota is not a complete authorization policy: delegated creation rights and pre-staged computer accounts need separate review.

#### Control Type

**Preventive**

#### Security Recommendation

1. Identify legitimate domain-join workflows and delegate narrowly scoped computer-creation rights to approved provisioning identities.
2. With an authorized administrator, set the domain attribute to zero, for example: `Set-ADDomain -Identity <domain> -Replace @{'ms-DS-MachineAccountQuota' = 0}`.
3. Pilot the join workflow and confirm the configured value. Missing attribute data produces Error, not an assumed default. The reported default comparison is a value comparison, not evidence that the value was never configured.

Consider pre-staging computer accounts or using dedicated provisioning identities and workstations for authorized joins.

#### How the Test Works

Reads the connected domain's `ms-DS-MachineAccountQuota` value and requires zero; unlike the former informational report, a nonzero value fails. Unavailable attribute data produces an error rather than a guessed default.

#### Related Tests

- **AD-DOM-01 — Domain functional level meets the highest supported common level** — `Test-MtAdDomainFunctionalLevel` — Reviews the domain functional level.
- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories domain controllers.

#### Related links

* [Microsoft Defender for Identity: Prevent non-privileged users from registering computers](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/allow-non-admins-register-computers)
* [ANSSI: Unrestricted domain joins](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_user_accounts_machineaccountquota)

<!--- Results --->
%TestResult%

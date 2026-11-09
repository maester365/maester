This inventory counts LDAP query policy objects in the Directory Service Query Policies container. Counting policies alone cannot establish effective LDAP limits: directory defaults and per-controller policy assignments also matter.

LDAP query policies define resource limits for directory requests. Appropriate limits help protect DC availability against:

- Expensive queries that consume CPU or memory.
- Large searches or excessive concurrent work that delay legitimate requests.
- Accidental application workloads or malicious queries that can cause resource exhaustion.

The count provides configuration visibility, not evidence that those risks are mitigated. A missing explicit policy or limit is not proof that queries are unlimited, because directory defaults may apply.

#### Control Type

**Operational**

#### Security Recommendation

Periodically review the configured policies and their assignments against directory workload and availability requirements. A policy count is not a target; avoid creating policies solely to increase it.

- Inspect actual `lDAPAdminLimits`, including supported page-size and query-duration limits, using the Microsoft LDAP-policy guidance below.
- Verify which query policy each relevant domain controller uses; a policy object can exist without being the effective policy on every DC.
- Align supported limits with legitimate application workloads and monitor latency, resource use and failures before tightening them.
- Combine resource limits with least-privilege access, workload monitoring and application query design. Do not assume a count of policy objects validates access controls.

#### How the Test Works

The test counts the LDAP query policy objects returned from the Directory Service Query Policies container. It does not evaluate the limits in those policies, determine which policy a domain controller uses, or measure effective limits.

#### Related Tests

- **AD-CFG-07 — Default query policy should be retrievable** — `Test-MtAdDefaultQueryPolicy` — Inventories the explicit default policy limits without establishing effective per-DC settings.

#### Remediation action

Review the policy values and policy assignments against your DC workload requirements. Investigate unexpected changes; do not add policies merely to meet a count.

Use `ntdsutil`'s **LDAP policies** context to inspect current settings on the intended server before making an approved change. Pilot changes with application owners and confirm effective behavior independently of this inventory count.

#### Related links

- [Microsoft: LDAP policies](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/view-set-ldap-policy-using-ntdsutil)

<!--- Results --->
%TestResult%

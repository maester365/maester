This inventory counts LDAP query policy objects in the Directory Service Query Policies container. Counting policies alone cannot establish effective LDAP limits: directory defaults and per-controller policy assignments also matter.

#### Control Type

**Operational**

#### Security Recommendation

Periodically review the configured policies and their assignments against directory workload and availability requirements. A policy count is not a target; avoid creating policies solely to increase it.

#### How the Test Works

The test counts the LDAP query policy objects returned from the Directory Service Query Policies container. It does not evaluate the limits in those policies, determine which policy a domain controller uses, or measure effective limits.

#### Related Tests

- **AD-CFG-07 — Default query policy should be retrievable** — `Test-MtAdDefaultQueryPolicy` — Inventories the explicit default policy limits without establishing effective per-DC settings.

#### Remediation action

Review the policy values and policy assignments against your DC workload requirements. Investigate unexpected changes; do not add policies merely to meet a count.

#### Related links

- [Microsoft: LDAP policies](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/view-set-ldap-policy-using-ntdsutil)

<!--- Results --->
%TestResult%

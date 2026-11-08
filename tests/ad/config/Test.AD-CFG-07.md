This check inventories the `Default-Query-Policy` object and any explicit `lDAPAdminLimits` values. If the object or explicit limits are absent, effective LDAP limits may still be supplied by directory defaults; absence alone is not proof that LDAP queries are unlimited.

#### Control Type

**Operational**

#### Security Recommendation

Review effective query limits against directory workload and availability requirements. Preserve room for legitimate searches and account for per-controller settings; do not treat an absent explicit value as an unlimited query or a configuration failure.

#### How the Test Works

The test retrieves the `Default-Query-Policy` entry from the query-policy inventory and reports its `lDAPAdminLimits` when available. It does not resolve all effective defaults or per-controller overrides.

#### Remediation action

Review effective LDAP query policy limits and any per-DC overrides before changing settings. Confirm that limits accommodate legitimate applications and are aligned with your organization's availability baseline.

#### Related Tests

- **AD-CFG-06 — LDAP query policy count should be retrievable** — `Test-MtAdLdapQueryPolicyCount` — Counts query policy objects; it does not establish effective limits.

#### Related links

- [Microsoft: LDAP policies](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/view-set-ldap-policy-using-ntdsutil)

<!--- Results --->
%TestResult%

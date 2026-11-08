`dSHeuristics` is a position-dependent string on the Directory Service configuration object. An unset attribute is not the same as an unreadable directory configuration. Each position controls a different behavior; dividing its length by two does not count enabled settings.

#### Control Type

**Operational**

#### Security Recommendation

Maintain a documented, forest-specific baseline for any `dSHeuristics` positions your organization uses. Review changes with an Active Directory specialist; do not change the string wholesale or infer risk from its length.

#### How the Test Works

The test reports the raw `dSHeuristics` value from the Directory Service configuration object, or `(not set)` when the attribute is absent. It does not interpret individual positions or judge them against a universal secure value.

#### Related Tests

- **AD-CFG-06 — LDAP query policy count should be retrievable** — `Test-MtAdLdapQueryPolicyCount` — Inventories query policy objects separately; neither check proves effective LDAP security settings.

#### Remediation action

Compare the reported raw value (or unset state) against the documented settings for your forest and your organization's approved baseline. Investigate individual positions before changing them; there is no universally safe replacement string.

#### Related links

- [Microsoft ADTS: dSHeuristics](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/e5899be4-862e-496f-9a38-33950617d2c5)

<!--- Results --->
%TestResult%

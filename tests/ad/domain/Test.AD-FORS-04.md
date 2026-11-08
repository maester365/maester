Inventories the collector's cross-forest/cross-reference metadata for investigation. These directory references do not, by themselves, demonstrate active trust validation or effective access granted to external principals.

Cross-reference metadata helps administrators review the forest's naming context topology. References must not be equated with security principals granted access, active trusts or a confirmed compromise.

#### Control Type

**Operational**

#### Security Recommendation

Review the referenced naming contexts and their intended purpose, then cross-check AD-TRUST-01 and AD-TRUST-03 for actual trust configuration and SID-filtering assessment. Audit relevant group memberships and resource ACLs separately before drawing conclusions about external access. Document unexpected references and investigate changes through directory change logs.

#### How the Test Works

Reports the collector's forest cross-reference metadata and count. It does not enumerate foreign principals or evaluate their effective permissions.

#### Related Tests

- **AD-TRUST-01 — Trust count and configuration should be investigated** — `Test-MtAdTrustTotalCount` — Inventories forest trusts separately.
- **AD-TRUST-03 — Applicable trusts should have strong SID filtering with no weak findings** — `Test-MtAdTrustQuarantinedCount` — Reviews applicable trust SID filtering.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%

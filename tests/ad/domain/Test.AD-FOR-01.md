Checks the configured forest functional level against the common level supported by DCs in the connected domain. DCs in other domains are excluded from this connection-scoped assessment and counted in the result. A match is not proof that every forest domain has been assessed or that the forest can be raised to another level.

The forest level governs forest-wide directory capabilities. Running below the supported level can defer use of newer features, but this check does not verify whether any particular feature has been enabled.

#### Control Type

**Preventive**

#### Security Recommendation

1. Verify OS and supported-level evidence for every forest DC, including foreign-domain records with collection errors.
2. Upgrade incompatible legacy DCs and raise each domain's functional level as required.
3. Raise the forest level only when every DC and domain supports the target. Server 2025 level 10 requires 2025 DCs throughout the forest. Do not interpret an inaccessible DC as healthy or attempt to lower a level based on uncertain inventory.

Test application compatibility, schedule a maintenance window and document the change before raising the level.

#### How the Test Works

Reads the forest-level value, scopes the shared DC inventory to the connected domain, then compares that value with the scoped DCs' supported levels. Other-domain metadata failures do not block this scoped result and are not treated as healthy support. Missing or inconsistent metadata for an in-scope DC still produces an error. Before changing the forest level, separately verify all other domains, DCs, domain functional levels and application dependencies.

#### Related Tests

- **AD-DOM-01 — Domain functional level meets the highest supported common level** — `Test-MtAdDomainFunctionalLevel` — Reviews the domain functional level.
- **AD-FOR-02 — Forest domain inventory for review** — `Test-MtAdForestDomainCount` — Inventories forest domains.

#### Related links

* [Microsoft: Active Directory functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-functional-levels)
* [Microsoft: Raise domain and forest functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/raise-domain-forest-functional-levels)
* [ANSSI: Insufficient forest and domain functional levels](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_functional_level)

<!--- Results --->
%TestResult%

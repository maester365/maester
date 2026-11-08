Checks the forest functional level against the highest common level supported by all inventoried forest DCs, not just those in the connected domain. Raising the level enables newer forest capabilities but requires a planned compatibility and recovery assessment.

The forest level governs forest-wide directory capabilities. Running below the supported level can defer use of newer features, but this check does not verify whether any particular feature has been enabled.

#### Control Type

**Preventive**

#### Security Recommendation

1. Verify OS and supported-level evidence for every forest DC, including foreign-domain records with collection errors.
2. Upgrade incompatible legacy DCs and raise each domain's functional level as required.
3. Raise the forest level only when every DC and domain supports the target. Server 2025 level 10 requires 2025 DCs throughout the forest. Do not interpret an inaccessible DC as healthy or attempt to lower a level based on uncertain inventory.

Test application compatibility, schedule a maintenance window and document the change before raising the level.

#### How the Test Works

Compares the forest's configured functional level with the highest common level supported by DCs across every forest domain. Unknown OS metadata or failed collection in another domain must not be counted as healthy support.

#### Related Tests

- **AD-DOM-01 — Domain functional level meets the highest supported common level** — `Test-MtAdDomainFunctionalLevel` — Reviews the domain functional level.
- **AD-FOR-02 — Forest domain inventory for review** — `Test-MtAdForestDomainCount` — Inventories forest domains.

#### Related links

* [Microsoft: Active Directory functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-functional-levels)
* [Microsoft: Raise domain and forest functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/raise-domain-forest-functional-levels)
* [ANSSI: Insufficient forest and domain functional levels](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_functional_level)

<!--- Results --->
%TestResult%

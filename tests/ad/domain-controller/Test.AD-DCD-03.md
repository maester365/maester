Inventories read-only domain controllers and their sites for investigation. Microsoft recommends considering RODCs where writable-DC physical security cannot be guaranteed; a site named “branch” alone does not establish that risk or require an RODC.

RODCs maintain read-only directory replicas and can limit which credentials are cached in less-secure locations. Actual exposure depends on the password-replication policy and the site's physical and network controls, not just the presence of an RODC.

#### Control Type

**Operational**

#### Security Recommendation

Review physical safeguards, local administrative access, WAN reliability and the password-replication policy for each site before deciding whether an RODC is appropriate. Review which credentials may be cached and which privileged identities must be denied. Inventory does not prove those controls are effective. Include compromised-RODC recovery in the incident plan.

#### How the Test Works

Inventories RODCs and their recorded sites among forest DCs. It does not assess replication health, credential caches or whether a site requires a local DC.

#### Related Tests

- **AD-DCD-04 — Forest has at least one Global Catalog** — `Test-MtAdDcNonGlobalCatalogCount` — Reviews Global Catalog coverage.
- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.
- **AD-SITE-02 — Sites without local domain controllers meet the organization baseline** — `Test-MtAdSiteWithoutDcCount` — Reviews site coverage.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [Planning regional domain controller placement](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/planning-regional-domain-controller-placement)

<!--- Results --->
%TestResult%

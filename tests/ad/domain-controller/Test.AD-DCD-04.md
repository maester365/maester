Checks that the forest inventory includes at least one Global Catalog. A missing GC can disrupt forest-wide directory searches and authentication dependencies. This is a minimum availability baseline, not a requirement that every DC be a GC.

Global Catalogs hold a partial replica of forest objects for directory searches and universal-group-related authentication. Placement requirements vary by site topology and application needs; a configured GC flag alone does not prove service health.

#### Control Type

**Operational**

#### Security Recommendation

Verify GC metadata, then plan GC placement and availability for the domain/site topology in Active Directory Sites and Services. Account for the Infrastructure Master placement exception in multi-domain domains that do not have all-GC DCs and have Recycle Bin disabled. A configured GC flag does not prove connectivity or service health. Check actual GC replication and client reachability independently.

#### How the Test Works

Checks the forest DC inventory for at least one GC and reports the GC and non-GC distribution for context. It does not enforce a GC on every DC or in every site.

#### Related Tests

- **AD-DCD-03 — Read-only DC inventory for review** — `Test-MtAdDcReadOnlyCount` — Inventories read-only DCs.
- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.
- **AD-FOR-02 — Forest domain inventory for review** — `Test-MtAdForestDomainCount` — Inventories forest domains.

#### Related links

* [Microsoft: Plan Global Catalog server placement](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/planning-global-catalog-server-placement)

<!--- Results --->
%TestResult%

Inventories each forest DC's Global Catalog status by default. Set `AssessmentMode` in `TestSettings[].Parameters` to choose `Inventory`, `AllGlobalCatalogs`, or `MinimumForestCatalog`.

- **Inventory** (default): reports GC, non-GC and unknown states as **Investigate** without imposing a placement baseline.
- **AllGlobalCatalogs**: passes only when every inventoried DC is a GC; unknown status is Error, and any known non-GC is a failure.
- **MinimumForestCatalog**: preserves the optional minimum-availability baseline of at least one forest GC; unknown status is Error.

The Low priority and remediation attributes describe the optional policy failures. Inventory mode makes no pass/fail claim. Requiring all DCs to be GCs is an organizational choice, not a universal AD requirement.

Global Catalogs hold a partial replica of forest objects for directory searches and universal-group-related authentication. Placement requirements vary by site topology and application needs; a configured GC flag alone does not prove service health.

#### Control Type

**Operational**

#### Security Recommendation

Verify GC metadata, then plan GC placement and availability for the domain/site topology in Active Directory Sites and Services. Account for the Infrastructure Master placement exception in multi-domain domains that do not have all-GC DCs and have Recycle Bin disabled. A configured GC flag does not prove connectivity or service health. Check actual GC replication and client reachability independently.

#### How the Test Works

Reports controller name, site and status with visual indicators, plus GC, non-GC and unknown counts. Inventory mode accepts incomplete per-controller status for investigation but still errors on missing/empty DC inventory. Policy modes require known statuses before evaluating their selected rule. The shared forest scope is unchanged.

#### Related Tests

- **AD-DCD-03 — Read-only DC inventory for review** — `Test-MtAdDcReadOnlyCount` — Inventories read-only DCs.
- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.
- **AD-FOR-02 — Forest domain inventory for review** — `Test-MtAdForestDomainCount` — Inventories forest domains.

#### Related links

* [Microsoft: Plan Global Catalog server placement](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/planning-global-catalog-server-placement)

<!--- Results --->
%TestResult%

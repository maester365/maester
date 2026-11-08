Checks that the forest inventory includes at least one Global Catalog. A missing GC can disrupt forest-wide directory searches and authentication dependencies. This is a minimum availability baseline, not a requirement that every DC be a GC.

#### Remediation action

Verify GC metadata, then plan GC placement and availability for the domain/site topology in Active Directory Sites and Services. Account for the Infrastructure Master placement exception in multi-domain domains that do not have all-GC DCs and have Recycle Bin disabled. A configured GC flag does not prove connectivity or service health.

#### Related links

* [Microsoft: Plan Global Catalog server placement](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/planning-global-catalog-server-placement)

<!--- Results --->
%TestResult%

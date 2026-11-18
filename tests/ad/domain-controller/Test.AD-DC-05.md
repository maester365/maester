Assesses recommended FSMO role placement and lists each role's NTDS Settings DN, the role count, and distinct owner count. The Schema and Domain Naming Masters should be on the forest-root PDC; RID Master should share its domain PDC. In a multi-domain forest with non-GC DCs and Recycle Bin disabled, Infrastructure Master should be a non-GC. A read-only DC cannot own a role. Spreading roles across hosts is not inherently safer, and role placement alone does not prove availability.

FSMO roles coordinate schema changes, domain naming, RID allocation, PDC-emulator operations and infrastructure updates. Role ownership should be documented for maintenance and recovery; multiple role owners are not a substitute for backups, healthy replication or failover procedures.

#### Control Type

**Operational**

#### Security Recommendation

Review any placement findings and plan role transfers with AD administrators according to the Microsoft guidance below. Confirm current owner DNs and operational health before transferring roles; do not distribute roles merely to increase the holder count. Record owners and transfer/seizure procedures in the recovery plan.

#### How the Test Works

Checks FSMO owner NTDS Settings DNs against placement guidance and reports role and distinct-owner counts. It does not declare a DC healthy because it owns a role or require the five roles to be spread over several hosts.

#### Related Tests

- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories connected-domain controllers.
- **AD-DCD-04 — Global Catalog status should be reviewed or meet the configured policy** — `Test-MtAdDcNonGlobalCatalogCount` — Inventories GC status or evaluates the selected placement rule.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [FSMO placement and optimization](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/fsmo-placement-and-optimization-on-ad-dcs)

<!--- Results --->
%TestResult%

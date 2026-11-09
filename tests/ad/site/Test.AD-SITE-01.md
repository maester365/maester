Site inventory for review. AD sites model network topology for client service location and replication planning. A count alone does not establish that sites match physical locations or that authentication is resilient.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Document site purposes and periodically review site-to-subnet mappings as the network changes. Remove unused sites only after checking dependent services and replication design.

#### How the Test Works

Inventories configured AD site objects and reports their count for review. It does not turn a particular count into a security finding or infer whether every location needs its own site.

#### Related Tests

- **AD-SITE-02 — Sites without local domain controllers meet the organization baseline** — `Test-MtAdSiteWithoutDcCount` — Reviews sites without local DCs.
- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Reviews site/subnet associations.
- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

Site and subnet association health.

Includes site and subnet counts, sites with and without subnet associations, and subnets whose SiteObject is missing or does not match an existing full site DN. This check covers the inventory formerly reported by AD-SUB-01, AD-SUB-02 and AD-SUB-11.

Sites used for client location need accurate subnet associations. Unmapped or misassociated subnets can send clients to unintended DCs; an intentionally unused site need not have a subnet assignment.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects against the organization baseline, document intentional exceptions and correct unintended configuration with the directory and network owners.

Map production client networks to the appropriate sites and reassess assignments after network changes. Verify whether sites without subnets are intentionally inactive before removing them.

#### How the Test Works

Correlates subnet `SiteObject` full distinguished names with existing site DNs, reporting mapped and unmapped subnet counts alongside site association coverage. It does not assume that merely matching a site name is a valid association.

#### Related Tests

- **AD-SITE-01 — Site inventory for review** — `Test-MtAdSiteTotalCount` — Inventories all sites.
- **AD-SUB-08 — Hierarchical IPv4 prefix overview** — `Test-MtAdSubnetFirstOctetCount` — Inventories IPv4 prefix hierarchy.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

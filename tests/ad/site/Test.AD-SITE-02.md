Sites without local domain controllers meet the organization baseline.

Compares each site to domain controller site metadata. A site without a local DC may be intentional; use AllowedSitesWithoutDcs to record permitted site names. This check replaces AD-SITE-03.

Sites without local DCs may rely on WAN connectivity for authentication and directory lookups; this can be an intentional hub-and-spoke topology rather than an automatically unsafe configuration.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects against the organization baseline, document intentional exceptions and correct unintended configuration with the directory and network owners.

Assess WAN reliability and authentication demand before considering an RODC or another local DC. Monitor site and link health separately; record permitted exceptions in `AllowedSitesWithoutDcs`.

#### How the Test Works

Matches configured site DNs to DC site metadata and compares sites without local DCs with the organization's allowed-site list. The companion details inventory was consolidated into this check.

#### Related Tests

- **AD-SITE-01 — Site inventory for review** — `Test-MtAdSiteTotalCount` — Inventories all sites.
- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.
- **AD-DCD-03 — Read-only DC inventory for review** — `Test-MtAdDcReadOnlyCount` — Inventories read-only DCs.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

Counts distinct Active Directory site distinguished names containing inventoried DC objects and reports DCs whose site metadata is missing. This is a site/DC inventory, distinct from AD-SITE and AD-SUB checks of site and subnet configuration. It cannot establish physical location, network connectivity or authentication resilience.

Site-aware DC placement can improve service location and help plan WAN authentication traffic. A site DN is a directory assignment, not proof of geographic redundancy; sites without DCs may be intentional in a hub-and-spoke design.

#### Control Type

**Operational**

#### Security Recommendation

Review the inventory with Active Directory administrators. Confirm missing metadata and assess actual requirements before changing configuration. Evaluate branch connectivity, authentication demand and physical safeguards before placing additional DCs; verify health and availability separately.

#### How the Test Works

Counts distinct site DNs on inventoried DC objects and identifies missing site metadata. It does not compare the count to all configured sites or infer the location of a DC from its name.

#### Related Tests

- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories connected-domain controllers.
- **AD-DC-07 — Connected-domain DC operating systems meet the minimum supported release** — `Test-MtAdDcOperatingSystemCount` — Reviews connected-domain DC operating system support.
- **AD-SITE-02 — Sites without local domain controllers meet the organization baseline** — `Test-MtAdSiteWithoutDcCount` — Reviews site coverage.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%

Counts DC computer references belonging to the connected domain only, not the forest as a whole. Child domains can have DNS names ending in the connected domain's DNS root; their DCs must not be included. Inventory is not availability evidence.

This inventory supports capacity, disaster-recovery and site-coverage planning. A count alone cannot show whether the DCs are healthy, reachable or geographically redundant.

#### Control Type

**Operational**

#### Security Recommendation

Review the inventory with Active Directory administrators. Confirm missing metadata and assess actual requirements before changing configuration. Plan sufficient redundancy for the domain's authentication load, verify actual health and recovery arrangements separately, and consider RODCs where physical security warrants them rather than assuming every site needs a local writable DC.

#### How the Test Works

Counts and reports DC references scoped to the connected domain; it does not count foreign-domain DCs simply because their DNS names end in the same suffix.

#### Related Tests

- **AD-DOM-01 — Domain functional level meets the highest supported common level** — `Test-MtAdDomainFunctionalLevel` — Reviews the domain functional level.
- **AD-FOR-02 — Forest domain inventory for review** — `Test-MtAdForestDomainCount` — Inventories forest domains.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%

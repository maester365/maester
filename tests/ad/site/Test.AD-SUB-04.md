IPv6 subnet prefix inventory.

Lists actual IPv6 prefix lengths for review. A short prefix is not automatically a misconfiguration; this check replaces AD-SUB-05.

IPv6 clients need appropriate site mappings where IPv6 is deployed. Prefix length alone does not reveal whether the mapped range spans sites or whether a network is in use.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Document deployed IPv6 address plans and map IPv6 client ranges to the correct sites. Compare IPv4 and IPv6 topology where relevant, rather than assuming they must be identical.

#### How the Test Works

Reports configured IPv6 subnet prefixes and their actual prefix lengths, combining the previous IPv6 count and broad-prefix inventory. It does not test IPv6 reachability.

#### Related Tests

- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Reviews site/subnet associations.
- **AD-SUB-03 — Broad IPv4 subnet inventory** — `Test-MtAdSubnetCatchAllCount` — Inventories broad IPv4 subnets.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

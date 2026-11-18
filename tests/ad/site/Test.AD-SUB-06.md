IPv4 prefixes outside RFC1918 inventory.

Lists IPv4 prefixes not wholly contained in RFC1918 private ranges. This includes non-public special-use space; non-RFC1918 does not imply public or insecure. Replaces AD-SUB-07.

Unexpected address allocations can complicate routing, acquisition planning or site assignments. RFC1918 status alone cannot establish internet exposure or whether an organization's assigned public range is inappropriate internally.

#### Control Type

**Detective**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Check allocation ownership, routing and isolation before changing any reported prefix. Document intentional special-use or assigned ranges and investigate unrecognized entries with network owners.

#### How the Test Works

Finds IPv4 subnet CIDRs not wholly within the RFC1918 private ranges and lists the actual prefixes. This replaces the separate details check without labeling all findings public IPs.

#### Related Tests

- **AD-SUB-03 — Broad IPv4 subnet inventory** — `Test-MtAdSubnetCatchAllCount` — Inventories broad IPv4 subnets.
- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Reviews site/subnet associations.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)
* [RFC 1918: Address Allocation for Private Internets](https://www.rfc-editor.org/rfc/rfc1918)

<!--- Results --->
%TestResult%

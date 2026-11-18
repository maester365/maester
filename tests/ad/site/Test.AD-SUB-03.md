Broad IPv4 subnet inventory.

Lists actual IPv4 CIDRs with /16 or shorter prefixes for topology review; a broad subnet is not intrinsically invalid.

Broad prefixes can span networks served by different sites, making client site selection less precise. Whether a prefix is too broad depends on the organization's actual addressing and routing, not a universal /24 rule.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Where a reported prefix crosses site boundaries, consider more specific subnet mappings; document intentionally broad ranges and review them as topology changes.

#### How the Test Works

Lists configured IPv4 subnet CIDRs whose actual prefix length is /16 or shorter. This is an inventory for assessment, not an automatic failure for every broad range.

#### Related Tests

- **AD-SUB-06 — IPv4 prefixes outside RFC1918 inventory** — `Test-MtAdSubnetNonInternalCount` — Inventories non-RFC1918 IPv4 prefixes.
- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Reviews site/subnet associations.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

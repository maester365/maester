Hierarchical IPv4 prefix overview.

Reports one row per source IPv4 subnet, grouping its address by first, first two, and first three octets. It replaces AD-SUB-09 and AD-SUB-10; these address components are not claims about the configured CIDR prefix.

An address-group overview can help document allocation patterns and locate unexpected source entries. Octet groupings do not establish segmentation, remaining capacity or actual /8, /16 or /24 network boundaries.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Compare reported addresses with the organization's IP allocation plan and retain room for planned growth; verify overlaps or conflicts against the actual CIDR prefixes, not just matching octets.

#### How the Test Works

Reports each configured IPv4 subnet with its first, first-two and first-three address octets. This combines the former octet-count views while retaining one row per source subnet.

#### Related Tests

- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Reviews site/subnet associations.
- **AD-SUB-03 — Broad IPv4 subnet inventory** — `Test-MtAdSubnetCatchAllCount` — Inventories broad IPv4 subnets.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

A functioning Active Directory domain normally exposes its domain, configuration, schema, DomainDnsZones, and ForestDnsZones naming contexts. Missing core partitions can affect directory configuration, schema visibility, or AD-integrated DNS replication.

#### Remediation action
1. Confirm the assessed domain controller is advertising its default, configuration, schema, DomainDnsZones, and ForestDnsZones naming contexts.
2. Use `repadmin /showrepl`, `dcdiag /test:dns`, and DNS Manager to validate missing DNS application partitions.
3. Confirm the domain controller is enlisted in the expected application partitions before changing directory configuration.
4. Treat additional application partitions as valid unless independent evidence shows they are stale or unauthorized.

#### Related links
- [Microsoft Learn: Active Directory partitions](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/active-directory-logical-structure)
<!--- Results --->
%TestResult%
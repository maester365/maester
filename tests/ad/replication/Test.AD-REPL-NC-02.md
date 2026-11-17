Every assessed domain controller should advertise the mandatory domain, configuration, and schema naming contexts. A missing mandatory partition can affect directory data, configuration, or schema visibility.

`DomainDnsZones` and `ForestDnsZones` are Active Directory application partitions and are outside this test's core naming-context pass/fail result because they do not replicate to every domain controller.

##### Remediation action
- Investigate any missing domain, configuration, or schema naming context on the assessed domain controller.
- Validate the affected DC with `repadmin /showrepl`, Event Viewer, and a base-scope LDAP read.
- Review DNS application-partition enlistment separately with `dnscmd /enumdirectorypartitions` and `dnscmd /directorypartitioninfo <partitionFQDN>` when the server is expected to host AD-integrated DNS.
- Do not enlist or remove a DC from an application partition solely because it is not advertised; confirm DNS-server role and intended replication scope first.

##### Related links
- [Microsoft Learn: Active Directory partitions](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/active-directory-logical-structure)
- [Microsoft Learn: Application directory partitions](https://learn.microsoft.com/windows/win32/ad/about-application-directory-partitions)

%TestResult%
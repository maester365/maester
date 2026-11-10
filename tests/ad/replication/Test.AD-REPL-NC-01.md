Active Directory domain controllers advertise the directory partitions they host through RootDSE `namingContexts`. A partition that is advertised but cannot be read may indicate incomplete replication, an unavailable application partition, permissions problems, or a domain controller that is not ready to serve that partition.

#### Remediation action
1. Identify each unreadable naming context in the result.
2. Validate the partition on the assessed domain controller with `repadmin /showrepl`, Event Viewer, and a base-scope LDAP read.
3. Correct replication, connectivity, directory-service, or access problems before treating the domain controller as healthy.
4. Do not delete an application partition merely because it is unfamiliar; establish ownership and purpose first.

#### Related links
- [Microsoft Learn: RootDSE](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/96f7b086-1ca3-4764-9a08-33f8f7a543db)
<!--- Results --->
%TestResult%
Checks every inventoried forest DC against the configurable minimum Windows Server release (default 2022). Reports each DC's directory OS name, OS version and classified release alongside counts and the baseline decision. Missing or conflicting OS metadata is an error. Directory metadata does not verify patch installation or contractual support.

#### Remediation action

Plan replacement or upgrade of DCs below the chosen minimum with AD administrators; verify replication, roles and application dependencies before decommissioning an older DC. Independently assess installed updates and vendor support.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%

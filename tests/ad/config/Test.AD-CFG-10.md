This check inventories objects in the WellKnown Security Principals configuration container. The number of entries can differ across versions and forests; neither 27 nor 33 is a universal baseline. A count alone does not identify malicious principals.

#### Remediation action

Review the identity and SID of any unexpected entry against an appropriate forest-specific reference before changing the directory. Investigate suspected unauthorized changes in directory audit logs.

#### Related links

- [Microsoft: special identity groups and their directory locations](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-special-identities-groups)

<!--- Results --->
%TestResult%

This check inventories objects in the WellKnown Security Principals configuration container. The number of entries can differ across versions and forests; neither 27 nor 33 is a universal baseline. A count alone does not identify malicious principals.

#### Control Type

**Operational**

#### Security Recommendation

Review unexpected identities and SIDs against a forest- and version-appropriate reference. Restrict changes to authorized administrators and use directory auditing to investigate suspected unauthorized modifications.

#### How the Test Works

The test enumerates and counts objects in the WellKnown Security Principals configuration container. It does not compare the count with a fixed expected value or classify entries as malicious.



#### Remediation action

Review the identity and SID of any unexpected entry against an appropriate forest-specific reference before changing the directory. Investigate suspected unauthorized changes in directory audit logs.

#### Related links

- [Microsoft: special identity groups and their directory locations](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-special-identities-groups)

<!--- Results --->
%TestResult%

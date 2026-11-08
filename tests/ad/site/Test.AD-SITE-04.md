Site and subnet association health.

Includes site and subnet counts, sites with and without subnet associations, and subnets whose SiteObject is missing or does not match an existing full site DN. This check covers the inventory formerly reported by AD-SUB-01, AD-SUB-02 and AD-SUB-11.

#### Remediation action

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects against the organization baseline, document intentional exceptions and correct unintended configuration with the directory and network owners.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

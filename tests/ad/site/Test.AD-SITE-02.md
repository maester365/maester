Sites without local domain controllers meet the organization baseline.

Compares each site to domain controller site metadata. A site without a local DC may be intentional; use AllowedSitesWithoutDcs to record permitted site names. This check replaces AD-SITE-03.

#### Remediation action

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects against the organization baseline, document intentional exceptions and correct unintended configuration with the directory and network owners.

#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/designing-the-site-topology)

<!--- Results --->
%TestResult%

Inventories read-only domain controllers and their sites for investigation. Microsoft recommends considering RODCs where writable-DC physical security cannot be guaranteed; a site named “branch” alone does not establish that risk or require an RODC.

#### Remediation action

Review physical safeguards, local administrative access, WAN reliability and the password-replication policy for each site before deciding whether an RODC is appropriate. Review which credentials may be cached and which privileged identities must be denied. Inventory does not prove those controls are effective.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [Planning regional domain controller placement](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/planning-regional-domain-controller-placement)

<!--- Results --->
%TestResult%

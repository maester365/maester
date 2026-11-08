Assesses recommended FSMO role placement and lists each role's NTDS Settings DN, the role count, and distinct owner count. The Schema and Domain Naming Masters should be on the forest-root PDC; RID Master should share its domain PDC. In a multi-domain forest with non-GC DCs and Recycle Bin disabled, Infrastructure Master should be a non-GC. A read-only DC cannot own a role. Spreading roles across hosts is not inherently safer, and role placement alone does not prove availability.

#### Remediation action

Review any placement findings and plan role transfers with AD administrators according to the Microsoft guidance below. Confirm current owner DNs and operational health before transferring roles; do not distribute roles merely to increase the holder count.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [FSMO placement and optimization](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/fsmo-placement-and-optimization-on-ad-dcs)

<!--- Results --->
%TestResult%

Inventories disabled GPO links, including the GPO and linked container for each disabled link. A disabled link can be intentional, but can also leave security settings unapplied. The count is of links, not distinct GPOs, and includes links that are both disabled and enforced. The result requires investigation rather than making a risk judgement.

#### Remediation action

1. In **Group Policy Management**, navigate to the listed organizational unit, domain or site and inspect its linked GPOs.
2. Re-enable links that should apply, remove obsolete links, and document intentional exceptions. Confirm inherited policy before changing links.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

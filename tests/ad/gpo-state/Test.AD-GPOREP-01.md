Checks for Group Policy objects whose security descriptor has no permission entries. An empty DACL needs investigation because it can disrupt policy management and application. Unreadable descriptors are listed separately and never treated as clean.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPO's **Delegation** and **Advanced** security settings.
2. Restore the intended permissions and confirm that authorized administrators and policy recipients retain the required access. Investigate any GPO whose descriptor could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

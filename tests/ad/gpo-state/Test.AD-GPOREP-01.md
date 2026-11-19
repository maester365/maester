Checks for Group Policy objects whose security descriptor has no permission entries. An empty DACL can disrupt policy management and application. Unreadable descriptors are listed separately and never treated as clean. If none can be evaluated, the check is skipped; partial collection without findings requires investigation.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPO's **Delegation** > **Advanced** security settings.
2. Restore intended permissions and confirm that authorized administrators and policy recipients retain required access. Investigate descriptors that could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

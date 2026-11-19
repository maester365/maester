Inventories GPOs with non-empty WMI filter references and reports those references. The **Investigate** result is informational: filters affect policy targeting, but their presence alone is not a security finding. If no filters are found, the summary says so without an empty details table; failed GPO inventory collection is an error.

#### Remediation action

Review each filter's query and intended scope with its owner. Confirm that linked policies target the intended computers and users, and remove or revise filters only through the normal policy change process.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

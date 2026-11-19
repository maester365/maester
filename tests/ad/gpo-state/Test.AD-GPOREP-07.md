Checks Group Policy objects for deny access entries and lists affected policies. Deny ACEs can override intended permissions and prevent security policy application. Any deny entry is flagged for review, even when intentional; the check does not calculate effective permissions. Unreadable descriptors are not treated as clean. This check requires Windows for security-descriptor parsing.

#### Remediation action

1. In **Group Policy Management**, inspect listed GPOs under **Delegation** > **Advanced**.
2. Confirm each deny entry is required and does not prevent intended policy application. Remove unintended entries after reviewing inheritance and scope; document intentional restrictions.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

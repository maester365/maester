Inventories Group Policy objects with deny access entries. Deny ACEs override allow entries, but can also be intentional. Policies with unreadable security descriptors are listed as not evaluated.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPOs under **Delegation** > **Advanced**.
2. Confirm each deny entry is required and does not prevent intended policy application; remove unintended entries after reviewing inheritance and scope.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

Inventories the total number of GPOs returned from Active Directory. The **Investigate** result is intentional: the count is a starting point for reviewing policy sprawl, ownership, and purpose, not a security finding. If no GPOs are returned, the summary says so; failed inventory collection is an error.

#### Remediation action

Review the inventory and confirm that each GPO has an owner and purpose. Consolidate only policies with compatible scope and settings. Archive or remove a policy only after confirming it is no longer needed.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

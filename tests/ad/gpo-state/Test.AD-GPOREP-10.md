Checks that every GPO has an allow entry for the Apply Group Policy right. A policy without application rights cannot deliver its intended settings through that right. This is a policy-health check, not a calculation of effective permissions for every user or computer.

The check fails when an application entry is absent and errors when permissions are unreadable. Intentionally unused policies require review before granting access; archive or remove them if they are no longer needed.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPO's **Scope** > **Security Filtering** and **Delegation** > **Advanced** settings.
2. Grant Apply Group Policy only to principals that should receive the policy. Document intentionally unused policies and investigate unreadable permissions.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

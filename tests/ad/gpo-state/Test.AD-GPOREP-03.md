Inventories GPOs without an Authenticated Users allow entry. An alternative security-filtering group may be intentional; a missing entry alone does not prove the GPO is insecure. Unreadable permissions are reported separately.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** > **Security Filtering** and **Delegation** settings.
2. Confirm that intended users or computers can read and apply the GPO; add an appropriate allow entry only when necessary. Investigate permissions that could not be evaluated.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

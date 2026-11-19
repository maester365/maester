Counts distinct GPOs with at least one enabled link and reports them against the GPO inventory. The **Investigate** result is informational: an enabled link does not establish that a policy is effective for every user or computer. Security filtering, WMI filters, inheritance, and policy processing also affect application. Failed collection or links with unknown state are errors.

The result reports total GPOs and counts with and without enabled links. It lists GPOs with enabled links when any are present.

#### Remediation action

Review linked and unlinked policies against intended scope. Check disabled links, security filtering, inheritance, WMI filters, and ownership before enabling, removing, or consolidating policies.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

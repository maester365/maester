Inventories GPOs with disabled settings, separating **all settings disabled**, **user settings disabled**, and **computer settings disabled**. These categories are disjoint. Unknown or unrecognized status values are reported separately and are not counted as enabled. The **Investigate** result does not judge whether a disabled category is appropriate. Failed GPO inventory collection is an error.

The result reports total GPOs and counts for each disabled category and unknown status. It lists policies with disabled or unknown status when any exist; a clean inventory has no empty details table.

#### Remediation action

Review each listed policy with its owner and confirm whether its disabled settings or unknown status are intentional. Check the policy's scope and change history before enabling settings; document approved exceptions.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

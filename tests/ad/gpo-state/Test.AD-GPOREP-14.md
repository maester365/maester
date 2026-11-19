Inventories distinct GPOs that have at least one enforced link. The **Investigate** result is informational, not a pass/fail judgement about enforcement. Enforcement overrides **Block Inheritance**; it does not block inheritance. This check counts policies, unlike `AD-GPOL-04`, which evaluates each enforced link and fails when any are found. The cached link inventory distinguishes an unlinked policy (known unenforced) from failed link collection (unknown). Failed GPO metadata collection is an error.

The summary and metrics table report total GPOs, those with an enforced link, and those with unknown enforcement. Details appear only for GPOs with enforced or unknown state; otherwise, the summary says no enforced links were found.

#### Remediation action

Review each listed policy's owner, enforced link, target, and settings in **Group Policy Management**. Confirm that the override is required by the policy design before changing it. If not, assess the effect on inheritance and remove the enforced flag through the normal change process; do not disable enforcement blindly. Investigate unknown enforcement state.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

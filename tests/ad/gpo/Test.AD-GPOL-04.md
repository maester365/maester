Checks individual GPO link entries for **Enforced** state. It passes when no enforced links are found and fails when any are found; missing link collection or unknown enforcement state is an error. Enforcement overrides **Block Inheritance** at lower levels. It does not block inheritance.

This is a link-scope hygiene check. Changes should be assessed with the policy owner before altering inheritance behavior.

This check evaluates each link entry, unlike `AD-GPOREP-14`, which reports distinct GPOs that have any enforced link and always returns **Investigate**. Enforcement can be intentional; a finding is a prompt to review the override, not an instruction to disable it.

#### Remediation action

Review each enforced link's purpose, owner, target, and settings in **Group Policy Management**. Confirm whether the override is required by the policy design before changing it. If not, assess the effect on inheritance and remove the enforced flag through the normal change process; do not disable enforcement blindly.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

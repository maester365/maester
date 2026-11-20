Checks individual GPO link entries for **Enforced** state. It passes when no enforced links are found and fails when any are found. Enforcement overrides **Block Inheritance** at lower levels; it does not block inheritance. A finding is a hygiene prompt to review the override, not an instruction to disable intentional enforcement.

#### Why This Test Matters

An enforced parent link can continue to apply settings where a lower-level OU blocks inheritance. This can be important by design, but may also make a policy's reach broader than administrators expect. Reviewing enforced links helps make that behavior understood and intentional; enforcement alone does not show that a policy is unsafe.

#### Control Type

**Detective** — this check fails when any collected link is enforced, to prompt review. It does not change the link or decide whether the override is justified.

#### Security Recommendation

- Review every enforced link's owner, target, policy purpose, and settings.
- Confirm that the override is required and that its effect on lower-level containers is understood.
- Do not remove enforcement solely to obtain a passing result; assess policy behavior and intended inheritance first.

#### How the Test Works

The test examines each collected GPO link entry and counts entries with `IsEnforced` set to true. It passes if the count is zero and fails if one or more links are enforced. It reports total and enforced link counts and lists each enforced GPO and linked container.

Missing link collection or an unknown enforcement state causes an error. This check counts link entries, unlike [AD-GPOREP-14](https://maester.dev/docs/tests/AD-GPOREP-14), which reports distinct GPOs with any enforced link and always returns **Investigate**. Neither result determines whether enforcement is appropriate.

#### Remediation action

Review each enforced link's purpose, owner, target, and settings in **Group Policy Management**. Confirm whether the override is required by the policy design before changing it. If it is not required, assess the effect on inheritance and remove the enforced flag through the normal change process; do not disable enforcement blindly.

#### Related Tests

- [AD-GPOL-05](https://maester.dev/docs/tests/AD-GPOL-05) reports OUs that block inheritance.
- [AD-GPOL-02](https://maester.dev/docs/tests/AD-GPOL-02) inventories disabled link entries.
- [AD-GPOREP-14](https://maester.dev/docs/tests/AD-GPOREP-14) inventories distinct GPOs with enforced links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

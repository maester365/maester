Checks individual GPO link entries for configured **Enforced** flags. It passes when no configured flags are found and fails when any are found, including on disabled links. Enabled enforced links override **Block Inheritance** at lower levels; disabled links do not apply and therefore do not actively override inheritance. A finding is a hygiene prompt to review the configured flag, not an instruction to disable intentional enforcement.

#### Why This Test Matters

An enforced parent link can continue to apply settings where a lower-level OU blocks inheritance. This can be important by design, but may also make a policy's reach broader than administrators expect. Reviewing enforced links helps make that behavior understood and intentional; enforcement alone does not show that a policy is unsafe.

#### Control Type

**Detective** — this check fails when any collected link is enforced, to prompt review. It does not change the link or decide whether the override is justified.

#### Security Recommendation

- Review every enforced link's owner, target, policy purpose, and settings.
- Confirm that the override is required and that its effect on lower-level containers is understood.
- Do not remove enforcement solely to obtain a passing result; assess policy behavior and intended inheritance first.

#### How the Test Works

The test examines each collected GPO link entry and counts entries with `IsEnforced` set to true. It passes if the count is zero and fails if one or more flags are configured. It separately reports enabled enforcement overrides, disabled flagged links, and flagged links with unknown enabled/disabled state. Details include the GPO ID, container, and link state. This preserves the configured-flag rule rather than silently exempting disabled flags.

Missing link collection or unknown enforcement state causes an error. An incomplete parsed link map cannot prove the absence of configured flags; known configured flags remain findings. This check counts link entries, unlike [AD-GPOREP-14](https://maester.dev/docs/tests/AD-GPOREP-14), which reports distinct GPOs with configured enforcement flags and always returns **Investigate**. Neither result determines whether enforcement is appropriate.

#### Remediation action

Review each enforced link's purpose, owner, target, and settings in **Group Policy Management**. Confirm whether the override is required by the policy design before changing it. If it is not required, assess the effect on inheritance and remove the enforced flag through the normal change process; do not disable enforcement blindly.

#### Related Tests

- [AD-GPOL-05 — OUs should not block Group Policy inheritance](https://maester.dev/docs/tests/AD-GPOL-05) (`Test-MtAdGpoBlockedInheritanceCount`) reports OUs whose inheritance blocks may be overridden by enforced links.
- [AD-GPOL-02 — Disabled GPO link inventory](https://maester.dev/docs/tests/AD-GPOL-02) (`Test-MtCheckADGPOL02`) inventories disabled link entries, a separate link state.
- [AD-GPOREP-14 — GPOs with enforced links should be investigated](https://maester.dev/docs/tests/AD-GPOREP-14) (`Test-MtAdGpoEnforcementCount`) inventories distinct GPOs with enforced links rather than assessing each link entry for failure.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

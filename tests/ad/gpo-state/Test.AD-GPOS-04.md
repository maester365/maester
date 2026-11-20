Inventories GPOs with disabled settings, separating **all settings disabled**, **user settings disabled**, and **computer settings disabled**. These categories are disjoint. Unknown or unrecognized statuses are reported separately and are not counted as enabled. The **Investigate** result does not judge whether a disabled category is appropriate.

#### Why This Test Matters

GPO status indicates which part of a policy is configured as disabled. Accidentally disabling a category can prevent its intended security settings from being applied. Disabling an unused category can also be deliberate and appropriate. The inventory supports owner review but does not label every disabled setting a security problem.

#### Control Type

**Operational** — this test inventories policy status for investigation; it does not evaluate whether disabled settings are appropriate.

#### Security Recommendation

- Confirm with the policy owner whether each disabled category is intentional and documented.
- Review policy scope and change history before enabling settings, since doing so may affect users or computers.
- Investigate unknown status values rather than treating them as enabled or assuming they indicate a disabled policy.

#### How the Test Works

The test maps known GPO status values to four categories: `0` = all settings disabled, `1` = user settings disabled, `2` = computer settings disabled, and `3` = all settings enabled. The three disabled categories are mutually exclusive. Unrecognized or missing values are labeled **Unknown**, reported separately, and never counted as enabled.

The result reports total GPOs, counts for each disabled category, and the unknown-status count. It lists policies with disabled or unknown status when any exist and does not render an empty details table otherwise. Successful collection always returns **Investigate**; unavailable GPO inventory is an error.

These rules apply to the collected `GpoStatus` value. The collector currently maps
an absent directory `flags` attribute to the enabled status, so this inventory is
not proof that every underlying LDAP attribute was returned.

#### Remediation action

Review each listed policy with its owner and confirm whether its disabled settings or unknown status are intentional. Check the policy's scope and change history before enabling settings; document approved exceptions. Investigate unknown status through inventory or data-quality review rather than guessing the intended state.

#### Related Tests

- [AD-GPO-01 — GPO inventory should be investigated](https://maester.dev/docs/tests/AD-GPO-01) (`Test-MtAdGpoTotalCount`) reports the total GPO inventory for context.
- [AD-GPOS-02 — GPO WMI filters should be investigated](https://maester.dev/docs/tests/AD-GPOS-02) (`Test-MtAdGpoWmiFilterCount`) inventories GPOs with WMI filter references, a separate policy attribute.
- [AD-GPOREP-12 — Review disabled GPO links](https://maester.dev/docs/tests/AD-GPOREP-12) (`Test-MtCheckADGPOREP12`) inventories disabled links; link state and disabled policy settings are separate conditions.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

Checks whether any collected OU has `gpOptions` equal to `1`, which blocks Group Policy inheritance. It fails when one or more OUs block inheritance and passes when none do. Blocking inheritance is not by itself proof of a security gap: enforced parent links still apply.

#### Why This Test Matters

An inheritance block can prevent settings from parent-linked GPOs from flowing to child OUs and may therefore be important to understand when evaluating policy scope. It may also be a deliberate exception. Knowing which OUs use it helps owners verify that the resulting configuration matches directory design.

#### Control Type

**Detective** — this test identifies OUs that block inheritance for review; it does not remove the block or establish whether required settings are missing.

#### Security Recommendation

- Document the reason and owner for each OU that blocks inheritance.
- Verify required settings through effective policy review, including any enforced parent links and local or directly linked policies.
- Change inheritance only after assessing its effects on the OU and its descendants.

#### How the Test Works

The test examines collected OU link-container data and checks `gpOptions`. A value of `1` indicates blocked inheritance; an unset value uses the default behavior, with inheritance enabled, and is not treated as unknown. The test reports the total OU count and the number that block inheritance, listing affected OUs when present.

The test fails if one or more OUs block inheritance and passes if none do. Failure to collect OU/link-container data causes an error rather than a clean result. Enforced parent links still apply across a lower-level inheritance block.

#### Remediation action

Review each listed OU with its owner and confirm the business or technical reason for blocking inheritance. Verify that required security settings are otherwise applied, including settings from enforced parent links. Remove the block only after assessing policy scope and the effect on the OU and its child OUs.

#### Related Tests

- [AD-GPOL-03 — Direct GPO link coverage should be investigated](https://maester.dev/docs/tests/AD-GPOL-03) (`Test-MtAdGpoUnlinkedTargetCount`) inventories targets without a direct GPO link.
- [AD-GPOL-04 — GPO links should not use enforcement](https://maester.dev/docs/tests/AD-GPOL-04) (`Test-MtAdGpoEnforcedCount`) reviews enforced links that override inheritance blocking.
- [AD-GPOL-01 — GPOs with enabled links should be investigated](https://maester.dev/docs/tests/AD-GPOL-01) (`Test-MtAdGpoLinkedCount`) inventories GPOs with enabled links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

Inventories disabled GPO link entries. It reports total, enabled, and disabled link counts and lists disabled links when present. A disabled link may be intentional; this inventory does not decide whether a policy should apply or whether a disabled link is a security gap.

#### Why This Test Matters

Disabled links can reflect a deliberate design, a temporary change, or an action that was not revisited. Knowing where they are helps owners check policy intent and avoid confusion during troubleshooting or review. Their presence alone does not establish risk.

#### Control Type

**Operational** — this is an inventory of disabled links, not an assessment of whether each should be enabled.

#### Security Recommendation

- Document the reason and owner for disabled links that are intentionally retained.
- Confirm desired scope and inherited policy before re-enabling or removing a link.
- Treat the inventory as a review aid; do not change a link solely to clear the listing.

#### How the Test Works

The test calls the shared disabled-link inventory, which reads collected GPO and link data and counts link entries by enabled or disabled state. It reports total, enabled, and disabled links and lists the associated GPO and linked container when disabled entries exist. A link that is both disabled and enforced remains part of the disabled-link inventory.

Missing GPO or link collection, or an unknown link state, causes an error. When collection succeeds, this test retains its default **Info/Passed** outcome even when disabled links are found. [AD-GPOREP-12](https://maester.dev/docs/tests/AD-GPOREP-12) uses the same inventory with an **Investigate** outcome; neither result assigns risk to an individual link.

#### Remediation action

1. In **Group Policy Management**, locate each listed domain, OU, or site and review its disabled links with the policy owner.
2. Re-enable links that should apply, remove obsolete links, and document intentional exceptions. Check inherited policy, filtering, and intended scope before changing a link.

#### Related Tests

- [AD-GPOL-01](https://maester.dev/docs/tests/AD-GPOL-01) inventories GPOs with enabled links.
- [AD-GPOL-04](https://maester.dev/docs/tests/AD-GPOL-04) checks enforced link entries.
- [AD-GPOREP-12](https://maester.dev/docs/tests/AD-GPOREP-12) presents the disabled-link inventory for investigation.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

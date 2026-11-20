Inventories disabled GPO link entries, including links that are both disabled and
enforced. Counts are link entries, not distinct GPOs. This read-only inventory
returns an informational **Investigate** result; it does not decide whether a
disabled link is appropriate or change link state.

#### Control Type

**Operational** — informational inventory

#### Why This Test Matters

A disabled link does not apply that GPO through that link, but the policy may be
linked elsewhere or received through another part of the hierarchy. Disabled
links can be intentional exceptions or temporary changes that need review. The
inventory provides policy and container context without asserting a policy gap.

#### Security Recommendation

Review disabled links with their policy owners. Confirm intended scope and
inheritance before enabling, removing, or retaining a link, and document approved
exceptions.

#### How the Test Works

When malformed targets make `GPOLinksComplete` false, only observed parsed-link
counts are reported. The partial inventory remains **Investigate**, and zero known
disabled links is not presented as proof that all links are enabled.

- Reads the cached GPO link and policy inventory and counts link entries by
  enabled or disabled state.
- Reports each disabled link with its GPO and linked container. Links that are
  both disabled and enforced remain included in the disabled count.
- Missing link or GPO collection, or an unknown link state, is an error. A
  successful inventory with no disabled links still returns **Investigate**.
- `AD-GPOL-02` uses the same inventory but retains its default **Info/Passed**
  outcome. Neither result judges an individual link's risk.

#### Remediation action

1. In **Group Policy Management**, locate each listed domain, OU, or site and
   review its disabled links with the policy owner.
2. Re-enable links that should apply, remove obsolete links, and document
   intentional exceptions. Confirm intended scope and inherited policy before
   changing a link.

#### Related Tests

- [AD-GPOL-02 — Disabled GPO link inventory](https://maester.dev/docs/tests/AD-GPOL-02) (`Test-MtCheckADGPOL02`) reports the same disabled-link inventory as Passed rather than Investigate.
- [AD-GPOL-01 — GPOs with enabled links should be investigated](https://maester.dev/docs/tests/AD-GPOL-01) (`Test-MtAdGpoLinkedCount`) inventories enabled links.
- [AD-GPOL-03 — Direct GPO link coverage should be investigated](https://maester.dev/docs/tests/AD-GPOL-03) (`Test-MtAdGpoUnlinkedTargetCount`) inventories direct link coverage across targets.
- [AD-GPOREP-14 — GPOs with enforced links should be investigated](https://maester.dev/docs/tests/AD-GPOREP-14) (`Test-MtAdGpoEnforcementCount`) inventories policies with enforced links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

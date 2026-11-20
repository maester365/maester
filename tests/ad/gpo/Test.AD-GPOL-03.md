Inventories direct GPO link coverage across collected OUs, the domain root, and sites. It counts and lists targets without a direct link and always returns **Investigate**. A target without a direct link may receive policy through inheritance, so the result does not establish an effective-policy gap.

#### Why This Test Matters

Direct-link coverage provides context for understanding directory policy layout and identifying targets whose intended policy path may need explanation. However, an OU, domain, or site without a direct link is not necessarily missing security policy: settings may flow from a parent or another applicable scope.

#### Control Type

**Operational** — the test reports direct-link inventory for review. It does not determine whether security requirements are effectively met.

#### Security Recommendation

- Compare the listed targets with the documented policy design and intended scope.
- Assess inherited policy and resultant application before concluding that a target has a coverage gap.
- Avoid adding direct links merely to make every target appear linked; unnecessary links can change policy processing.

#### How the Test Works

The test counts collected OUs, the domain root, and sites, then looks for GPO GUID references in each target's `gPLink` value. A GUID reference counts as a direct link even if the link is disabled or refers to a GPO that is not resolved here. It reports linked and unlinked target counts and lists targets without a direct reference.

The test does not evaluate link state, resolve every reference to an existing policy, or calculate resultant policy. Missing target collection causes an error. A successful inventory always receives **Investigate**, whether or not unlinked targets are found.

#### Remediation action

Review each target without a direct link against the intended design, including parent links, inheritance blocking, link state, and policy scope. Add a direct link only when that design requires it. If coverage remains unclear, verify effective policy through the appropriate policy assessment rather than inferring a gap from this inventory.

#### Related Tests

- [AD-GPO-04](https://maester.dev/docs/tests/AD-GPO-04) identifies GPOs without collected link references.
- [AD-GPOL-01](https://maester.dev/docs/tests/AD-GPOL-01) inventories distinct GPOs with enabled links.
- [AD-GPOL-05](https://maester.dev/docs/tests/AD-GPOL-05) reports OUs that block inheritance.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

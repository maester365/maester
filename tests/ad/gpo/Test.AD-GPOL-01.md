Inventories distinct GPOs that have at least one enabled link and reports them against the collected GPO inventory. The **Investigate** result is informational: an enabled link does not establish that a policy is effective for any particular user or computer.

#### Why This Test Matters

Link inventory helps administrators understand where policies are configured to be considered. Comparing enabled-link counts with the full inventory can support scope and lifecycle reviews, but neither a low nor high count proves that policy coverage is deficient or excessive.

#### Control Type

**Operational** — this test provides a view of configured links for investigation; it does not judge policy effectiveness or enforce a control.

#### Security Recommendation

- Review enabled links against intended policy scope and ownership.
- Evaluate effective policy separately: security filtering, WMI filters, inheritance, and policy processing affect application.
- Check before enabling or removing links, since either change can alter which users or computers receive settings.

#### How the Test Works

If a malformed link makes the parsed map incomplete, known enabled-link matches
are still listed, but the count of GPOs without enabled links is **Unknown**. The
summary explicitly marks this as a partial inventory rather than a clean result.

The test uses collected GPO and link data, identifies link entries with enabled state, and counts each distinct GPO once when it has at least one enabled link. It reports total GPOs, the count with enabled links, and the count without them; GPOs with enabled links are listed when present.

Missing inventory or link data, an unknown GPO identifier, or an unknown link state causes an error. The test does not evaluate security filtering, WMI query results, inheritance, or resultant policy. An enabled link is not proof of application.

#### Remediation action

Review policies with and without enabled links against their intended scope. Before enabling, removing, or consolidating a link, check the target, disabled links, security filtering, WMI filters, inheritance, ownership, and expected policy processing. Confirm any change in the relevant deployment scope.

#### Related Tests

- [AD-GPO-01 — GPO inventory should be investigated](https://maester.dev/docs/tests/AD-GPO-01) (`Test-MtAdGpoTotalCount`) reports the total GPO inventory for context.
- [AD-GPO-04 — GPOs should have at least one link](https://maester.dev/docs/tests/AD-GPO-04) (`Test-MtAdGpoUnlinkedCount`) identifies GPOs without any collected link reference, including disabled references.
- [AD-GPOL-02 — Disabled GPO link inventory](https://maester.dev/docs/tests/AD-GPOL-02) (`Test-MtCheckADGPOL02`) inventories disabled link entries rather than distinct GPOs with enabled links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

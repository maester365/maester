Inventories GPOs with non-empty WMI filter references and reports those references. The **Investigate** result is informational: WMI filters affect policy targeting, but their presence alone is not a security finding.

#### Why This Test Matters

WMI filters can constrain which computers receive a linked GPO. A poorly scoped filter can exclude intended computers from required security settings, and an inefficient query can delay policy processing. Reviewing their use and intended scope can help identify those issues. A filter reference by itself does not show that its query is incorrect or that a policy is applied inappropriately.

#### Control Type

**Operational** — this test inventories filter references for review; it does not evaluate their security or validate policy application.

#### Security Recommendation

- Review each filter's query and intended scope with its owner.
- Confirm that linked policies target the intended computers and users.
- Revise or remove a filter only after checking the effect on policy targeting and following the normal change process.

#### How the Test Works

The test reads the collected GPO inventory and counts entries whose `WmiFilter` reference is non-empty. It reports the total GPO count and the count with filter references, and lists the associated GPO and reference when filters are found. When none are found, the summary says so without an empty details table. Successful collection returns **Investigate**, whether or not references are found; failed GPO inventory collection is an error.

This check looks only for a non-empty reference. It does not parse or validate the full WMI query, establish whether the referenced filter is available, or determine which systems receive the policy. The collector cannot distinguish an attribute that was not returned from one that was returned blank, so an empty reference is not complete audit proof that no filter exists.

#### Remediation action

Review each reported filter's query and intended scope with its owner. Confirm that linked policies target the intended computers and users, and assess query behavior and performance. Remove or revise filters only through the normal policy change process.

#### Related Tests

- [AD-GPOL-01](https://maester.dev/docs/tests/AD-GPOL-01) inventories GPOs with enabled links.
- [AD-GPOS-04](https://maester.dev/docs/tests/AD-GPOS-04) inventories disabled user or computer settings.
- [AD-GPOREP-10](https://maester.dev/docs/tests/AD-GPOREP-10) checks explicit Apply Group Policy entries, another aspect of policy targeting.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

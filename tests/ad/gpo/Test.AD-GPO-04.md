Identifies GPOs whose identifiers do not appear in collected domain, OU, or site `gPLink` values. It counts references to a GPO whether a link is enabled or disabled; it does not determine whether settings are actively applied. An unlinked GPO may be intentionally retained and is not, by itself, a vulnerability.

#### Why This Test Matters

An unlinked policy can add inventory and maintenance overhead. If it is mistakenly linked later, unreviewed or obsolete settings can unexpectedly reach users or computers. Finding one is a prompt to verify its purpose and lifecycle, not evidence that the policy is exploitable or must be removed.

#### Control Type

**Detective** — the test detects GPOs with no collected link reference and reports them for review; it does not make a configuration change.

#### Security Recommendation

- Keep the purpose and owner of retained, unlinked GPOs documented.
- Before removal, confirm that the policy is not retained for a planned deployment, recovery, or other approved use.
- Review link scope and state separately; the presence of a link reference does not establish that the policy applies.

#### How the Test Works

The test compares each collected GPO identifier with GUID references from collected domain, OU, and site `gPLink` data. Disabled links count as references, as do references whose policy application is not established by this test. It reports total, linked, and unlinked GPO counts and lists unlinked policies when any are found.

Any GPO without a collected link reference fails the test. It passes when all collected GPOs have at least one reference, without asserting that those links are enabled or effective.

Missing GPO or link collection, or a GPO without an identifier, causes an error rather than a clean result. The test does not calculate resultant policy or determine whether any referenced GPO is enabled or effective.

#### Remediation action

1. In **Group Policy Management**, review each listed GPO's owner, purpose, backup, and change history.
2. If it is no longer needed, archive or remove it under the normal change process. Otherwise document why it is unlinked and retain it.
3. Do not infer a security gap or remove a policy solely because it has no link.

#### Related Tests

- [AD-GPO-01](https://maester.dev/docs/tests/AD-GPO-01) reports the total GPO inventory.
- [AD-GPOL-01](https://maester.dev/docs/tests/AD-GPOL-01) counts distinct GPOs with an enabled link.
- [AD-GPOL-03](https://maester.dev/docs/tests/AD-GPOL-03) inventories targets without a direct link.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

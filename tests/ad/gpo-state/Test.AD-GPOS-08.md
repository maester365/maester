Inventories distinct known owner identities across collected GPOs and groups policies by owner. Blank or missing owner values are reported as unknown, not counted as a distinct known owner. The **Investigate** result is informational: owner count alone does not establish whether ownership is appropriate or access is unauthorized.

#### Why This Test Matters

Identifiable ownership helps administrators review policy purpose, maintenance, and delegated management. Ownership can influence permission management; inappropriate ownership or delegation can permit unauthorized policy changes. Unknown ownership can make accountability harder, while multiple owners may be appropriate in a larger environment. The number of owners by itself does not demonstrate excessive access or poor control.

#### Control Type

**Operational** — this test inventories ownership information for review; it does not assess or change GPO permissions.

#### Security Recommendation

- Keep ownership and delegation current so policy changes have an accountable reviewer.
- Resolve blank or unrecognized ownership where possible, while distinguishing unknown data from known owners.
- Review the permissions governing GPO management separately; an owner count alone does not prove who can change a policy.

#### How the Test Works

The test groups collected GPOs by non-empty `Owner` values and reports the number of distinct known owner identities, the policy count for each, and associated policy names. GPOs with blank or missing owner values are grouped under unknown ownership and listed separately; they are not counted as an additional known owner. If the collector cannot translate an owner SID to a name, it retains the SID and counts it as a known identity. A counted SID does not establish that the account still exists or is an appropriate owner.

If no GPOs are returned, the summary says so without an empty details table. Failed GPO inventory collection is an error. The test does not inspect permissions, validate whether an owner is authorized, or decide whether the number of owners is appropriate. It always returns **Investigate** when collection succeeds.

#### Remediation action

Review each known owner and the policies assigned to them. Resolve unknown ownership where possible, and confirm that ownership and delegation are current and appropriate for each policy. If access is a concern, review GPO permissions directly rather than inferring authorization from this count.

#### Related Tests

- [AD-GPO-01 — GPO inventory should be investigated](https://maester.dev/docs/tests/AD-GPO-01) (`Test-MtAdGpoTotalCount`) reports the total GPO inventory for context.
- [AD-GPO-02 — GPOs should be modified within the configured age limit](https://maester.dev/docs/tests/AD-GPO-02) (`Test-MtAdGpoStale`) identifies policies whose last modification exceeds the configured age limit.
- [AD-GPOREP-09 — GPOs should not inherit permission entries](https://maester.dev/docs/tests/AD-GPOREP-09) (`Test-MtAdGpoInheritedPermissionsCount`) checks inherited permission entries, which can affect GPO delegation.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

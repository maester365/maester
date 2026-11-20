Checks whether each GPO's last modification is within the configured age limit, which defaults to five calendar years. The test fails if any modification date is older than that limit. A modification exactly at the cutoff passes. This is a maintenance indicator, not proof that a policy is insecure.

#### Why This Test Matters

Policies that have not changed for a long time may preserve obsolete settings or assumptions that no longer match the current security baseline. Stable policies can also be intentional. Reviewing older policies can reveal those settings or undocumented dependencies before a planned change; age by itself does not establish a security or operational defect.

#### Control Type

**Detective** — the test identifies policies outside the configured modification-age limit for review. It does not update or remove them.

#### Security Recommendation

- Review stale policies with their owners and compare their settings and scope with current requirements.
- Treat the modification date as a review signal, not as a quality score or reason to make an unnecessary edit.
- Confirm policy dependencies and intended application before changing or retiring a GPO.

#### How the Test Works

The test compares each collected GPO's `ModificationTime` with the current UTC date minus `MaximumModificationAgeYears` (five years by default). A modification exactly on the UTC cutoff is within the limit. It reports the total, stale count, cutoff, and each policy's creation and modification dates and assessment. An old creation date alone does not fail a recently modified GPO.

An empty or unavailable GPO inventory, or a missing modification date, causes an error because age cannot be assessed. The source modification timestamp is LDAP `whenChanged`, which is specific to the queried domain controller and can reflect metadata or ACL changes as well as policy changes. It is not a complete history of policy-setting changes.

Configure `MaximumModificationAgeYears` under `TestSettings` > `Parameters` for `AD-GPO-02` in
`maester-config.json`, or pass it through `Invoke-MtTest -Parameter`.

#### Remediation action

1. In **Group Policy Management**, review stale policies with their owners and compare their settings and scope with current requirements.
2. Update a policy only where review identifies a real need, then verify intended scope and behavior. Archive or remove policies only after confirming they are no longer required.
3. Do not make an unrelated edit merely to refresh the modification timestamp.

#### Related Tests

- [AD-GPO-01 — GPO inventory should be investigated](https://maester.dev/docs/tests/AD-GPO-01) (`Test-MtAdGpoTotalCount`) reports the total GPO inventory for context.
- [AD-GPO-04 — GPOs should have at least one link](https://maester.dev/docs/tests/AD-GPO-04) (`Test-MtAdGpoUnlinkedCount`) identifies GPOs without collected link references; it does not assess modification age.
- [AD-GPOL-01 — GPOs with enabled links should be investigated](https://maester.dev/docs/tests/AD-GPOL-01) (`Test-MtAdGpoLinkedCount`) inventories GPOs with enabled links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

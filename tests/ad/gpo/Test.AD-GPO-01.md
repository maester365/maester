Inventories the total number of Group Policy Objects (GPOs) returned from Active Directory. The **Investigate** result is intentional: the count is a starting point for understanding policy inventory, not a security finding.

#### Why This Test Matters

An inventory helps administrators understand how much policy configuration they maintain and gives context for reviews of scope, ownership, and purpose. A large or growing number of GPOs can make policy maintenance and conflict analysis harder, but the count alone does not show that a policy is redundant, unsafe, or effective on a particular computer or user.

#### Control Type

**Operational** — this test reports an inventory metric for review; it does not assess a security requirement or alter configuration.

#### Security Recommendation

- Keep a documented purpose and accountable owner for each GPO.
- Review scope and settings before consolidating policies; similar names do not mean their scope or contents are interchangeable.
- Retire a GPO only after confirming it is no longer needed and following the normal backup and change process.

#### How the Test Works

The test reads the collected GPO inventory and counts the returned GPO records. It reports the total and adds an **Investigate** result even when the collection is empty; in that case, the summary explicitly says that no GPOs were returned. If the inventory itself could not be retrieved, the test errors rather than treating missing data as an empty directory.

The result does not inspect policy settings, links, application, or whether two policies can safely be combined.

#### Remediation action

Review the inventory and confirm each policy's owner, purpose, and intended scope. Investigate apparent duplicates with their owners, and consolidate only policies with compatible settings and scope. Archive or remove a policy only after confirming it is no longer needed.

#### Related Tests

- [AD-GPO-02 — GPOs should be modified within the configured age limit](https://maester.dev/docs/tests/AD-GPO-02) (`Test-MtAdGpoStale`) reviews modification age for the inventoried GPOs.
- [AD-GPO-04 — GPOs should have at least one link](https://maester.dev/docs/tests/AD-GPO-04) (`Test-MtAdGpoUnlinkedCount`) identifies inventoried GPOs without collected link references.
- [AD-GPOL-01 — GPOs with enabled links should be investigated](https://maester.dev/docs/tests/AD-GPOL-01) (`Test-MtAdGpoLinkedCount`) counts inventoried GPOs with enabled links.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

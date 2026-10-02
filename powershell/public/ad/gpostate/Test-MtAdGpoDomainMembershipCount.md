#### Control Type

**Detective**

#### Test-MtAdGpoDomainMembershipCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts distinct domain memberships tied to GPOs which can reflect ownership and applicability scope.

#### Security Recommendation
- Review domain membership mapping for GPOs to ensure proper targeting and access control.

#### How the Test Works
- Retrieves GPO state, inspects Domain membership aspects, and reports a total count.

#### Related Tests
- `Test-MtAdGpoOwnerDistinctCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

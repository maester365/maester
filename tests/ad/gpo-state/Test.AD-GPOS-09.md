#### Test-MtAdGpoOwnerDetails

 Returns details of GPO owners, including how many GPOs each owner has.

#### Why This Test Matters
- Operational value: summarizes GPO owners and how many GPOs each owner has, revealing ownership distribution.

#### Control Type

**Operational**

#### Security Recommendation
- Ensure ownership aligns with policy and stewardship; adjust ownership for orphaned or unclear GPOs.

#### How the Test Works
- Retrieves GPO state, groups GPOs by Owner, and renders a table with owner and GPO counts.

#### Related Tests
- `Test-MtAdGpoOwnerDistinctCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

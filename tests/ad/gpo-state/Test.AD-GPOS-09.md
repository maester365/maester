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
- **AD-GPOS-08 — GPO owner distinct count should be investigated** — `Test-MtAdGpoOwnerDistinctCount` — Summarizes distinct GPO owners.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

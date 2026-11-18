#### Test-MtAdGpoOwnerDistinctCount

 Counts the number of distinct GPO owners.

#### Why This Test Matters
- Operational control: assesses diversity of GPO owners which can highlight unusual configurations or omissions.

#### Control Type

**Operational**

#### Security Recommendation
- If many owners are identical or blank, review GPO creation practices to ensure proper ownership.

#### How the Test Works
- Retrieves GPO state, extracts Owner fields, computes distinct non-empty owners, and reports the count.

#### Related Tests
- **AD-GPOS-09 — GPO owner details should be investigated** — `Test-MtAdGpoOwnerDetails` — Summarizes owners per GPO.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

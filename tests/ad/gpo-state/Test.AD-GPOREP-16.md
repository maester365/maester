#### Test-MtAdGpoVersionMismatchDetails

 Returns details of GPOs with a version mismatch.

#### Why This Test Matters
- Detective control: identifies GPOs where the version reported has a mismatch, potentially indicating stale or misapplied policy definitions.

#### Control Type

**Detective**

#### Security Recommendation
- Validate GPO versions against a known baseline and correct mismatches to ensure consistent policy behavior.

#### How the Test Works
- Fetches GPO state, filters GPOReports for HasVersionMismatch being true, and presents a table of mismatched GPOs.

#### Related Tests
- `Test-MtAdGpoVersionMismatchCount` - counts GPOs with version mismatches.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

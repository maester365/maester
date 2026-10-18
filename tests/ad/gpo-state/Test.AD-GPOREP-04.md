#### Control Type

**Detective**

#### Test-MtAdGpoNoAuthenticatedUsersDetails

 Returns details of GPO reports without Authenticated Users.

#### Why This Test Matters
- Detective control: detects GPO reports missing Authenticated Users which could widen access.

#### Security Recommendation
- Review GPOs missing Authenticated Users to ensure access controls are appropriate.

#### How the Test Works
- Obtains GPO state, selects the reports without an access-allowed entry for Authenticated Users (HasAuthenticatedUsers is false), and renders a details table.
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoNoAuthenticatedUsersCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

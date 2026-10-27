#### Control Type

**Detective**

#### Test-MtAdGpoNoAuthenticatedUsersCount

 Counts GPO reports that do not include Authenticated Users.

#### Why This Test Matters
- Detective control: counts GPO reports missing Authenticated Users which could widen access.

#### Security Recommendation
- Review missing Authenticated Users and adjust GPO ACLs as needed.

#### How the Test Works
- Uses Get-MtADGpoState, counts the GPO reports without an access-allowed entry for Authenticated Users (HasAuthenticatedUsers is false), and reports totals.
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoNoAuthenticatedUsersDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

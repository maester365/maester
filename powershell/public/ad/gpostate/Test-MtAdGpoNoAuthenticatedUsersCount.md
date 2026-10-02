#### Control Type

**Detective**

#### Test-MtAdGpoNoAuthenticatedUsersCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts GPO reports missing Authenticated Users which could widen access.

#### Security Recommendation
- Review missing Authenticated Users and adjust GPO ACLs as needed.

#### How the Test Works
- Uses Get-MtADGpoState, filters GPO reports for HasAuthenticatedUsers false or null, and reports totals.

#### Related Tests
- `Test-MtAdGpoNoAuthenticatedUsersDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

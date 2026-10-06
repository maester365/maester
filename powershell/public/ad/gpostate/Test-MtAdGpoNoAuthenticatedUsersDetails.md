#### Control Type

**Detective**

#### Test-MtAdGpoNoAuthenticatedUsersDetails

 Returns details of GPO reports without Authenticated Users.

#### Why This Test Matters
- Detective control: detects GPO reports missing Authenticated Users which could widen access.

#### Security Recommendation
- Review GPOs missing Authenticated Users to ensure access controls are appropriate.

#### How the Test Works
- Obtains GPO state, selects reports lacking HasAuthenticatedUsers or with false value, and renders a details table.

#### Related Tests
- `Test-MtAdGpoNoAuthenticatedUsersCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

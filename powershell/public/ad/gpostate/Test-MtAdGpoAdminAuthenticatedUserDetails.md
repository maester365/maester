#### Control Type

**Detective**

#### Test-MtAdGpoAdminAuthenticatedUserDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: lists Admin/AuthenticatedUser relationships in GPO scopes to ensure proper admin access control.

#### Security Recommendation
- Review admin/authenticated user mappings and tighten where necessary.

#### How the Test Works
- Retrieves GPO state, extracts details about Admin or Authenticated User mappings, and renders a Markdown table.

#### Related Tests
- `Test-MtAdGpoValidAccountsDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

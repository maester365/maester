#### Control Type

**Detective**

#### Test-MtAdGpoDenyAceDetails

 Returns details of GPO reports that include a Deny ACE.

#### Why This Test Matters
- Detective control: lists GPO reports that contain a Deny ACE which could block legitimate policy application.

#### Security Recommendation
- Review and minimize Deny ACE usage; remove unnecessary permissions to reduce risk.

#### How the Test Works
- Reads GPO state, selects reports where HasDenyAce is true, and outputs a Markdown table of such GPOs.

#### Related Tests
- `Test-MtAdGpoDenyAceCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

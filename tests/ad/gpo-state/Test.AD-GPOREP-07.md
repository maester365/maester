#### Control Type

**Detective**

#### Test-MtAdGpoDenyAceCount

 Counts GPO reports that include a Deny ACE.

#### Why This Test Matters
- Detective control: checks for Deny ACEs in GPO reports which can override permissions.

#### Security Recommendation
- Review or remove Deny ACEs to ensure proper permission handling.

#### How the Test Works
- Aggregates GPO reports, counts those with HasDenyAce true, and reports totals and a sample of affected GPOs.

#### Related Tests
- `Test-MtAdGpoDenyAceDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

#### Control Type

**Detective**

#### Test-MtAdGpoNoEnterpriseDcCount

 Counts GPO reports that do not include Enterprise Domain Controllers.

#### Why This Test Matters
- Detective control: flags GPO reports missing Enterprise Domain Controllers which could impact domain-wide policy targeting.

#### Security Recommendation
- Verify whether Enterprise DCs should be included; adjust policy accordingly.

#### How the Test Works
- Retrieves GPO state, enumerates GPO reports, and counts those without Enterprise Domain Controllers.

#### Related Tests
- `Test-MtAdGpoNoEnterpriseDcCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

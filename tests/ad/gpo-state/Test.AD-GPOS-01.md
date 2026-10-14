#### Test-MtAdGpoStateTotalCount

 Counts the total number of Group Policy Objects (GPOs) returned by Get-MtADGpoState.

#### Why This Test Matters
- Operational control: provides a quick overview of the total GPOs present in the AD state to gauge scope.

#### Control Type

**Operational**

#### Security Recommendation
- Use as a baseline metric; no remediation required unless counts look unexpectedly abnormal.

#### How the Test Works
- Calls Get-MtADGpoState, counts non-null GPOs in the GPOs collection, and reports a Markdown table with a single Total GPOs value.

#### Related Tests
- `Test-MtAdGpoStateTotalCount` is the primary reference.

#### Related links
- [Microsoft Learn - Group Policy overview](https://learn.microsoft.com/windows-server/group-policy/)
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%

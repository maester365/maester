#### Test-MtAdGpoNoApplyGroupPolicyAceCount

 Counts the number of GPOs missing the "Apply Group Policy" ACE.

#### Why This Test Matters
- Detective control: counts GPOs missing the Apply Group Policy ACE which governs policy application.

#### Control Type

**Operational**

#### Security Recommendation
- Ensure the ACE is present on necessary GPOs or document why it is absent.

#### How the Test Works
- Evaluates GPO reports for HasApplyGroupPolicyAce, counts missing ACE occurrences, and provides a sample list.

#### Related Tests
- `Test-MtAdGpoNoApplyGroupPolicyAceDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

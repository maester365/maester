#### Test-MtAdGpoNoApplyGroupPolicyAceDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: lists GPOs missing the Apply Group Policy ACE, which governs how policy is applied.

#### Control Type

**Operational**

#### Security Recommendation
- Ensure required ACE is present or document why it is absent.

#### How the Test Works
- Reads GPO state, filters for reports where HasApplyGroupPolicyAce is false, and outputs a Markdown table of findings.

#### Related Tests
- `Test-MtAdGpoNoApplyGroupPolicyAceCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

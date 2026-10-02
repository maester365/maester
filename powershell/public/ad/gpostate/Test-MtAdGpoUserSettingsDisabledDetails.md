#### Test-MtAdGpoUserSettingsDisabledDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: looks for GPOs where user settings are disabled, which can impact user policy delivery.

#### Control Type

**Operational**

#### Security Recommendation
- Review user-disabled GPOs and confirm whether disabling is intentional per policy.

#### How the Test Works
- Gets GPO state, filters for reports where the UserDisabled status is true and renders a details table including display name and status.

#### Related Tests
- `Test-MtAdGpoUserSettingsDisabledDetails` (self reference for template clarity).

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

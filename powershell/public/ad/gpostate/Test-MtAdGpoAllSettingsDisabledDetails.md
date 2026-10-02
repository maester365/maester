#### Test-MtAdGpoAllSettingsDisabledDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: lists GPOs where all settings are disabled which can be a sign of misconfiguration or excessive restriction.

#### Control Type

**Operational**

#### Security Recommendation
- Review fully disabled GPOs; decide whether to re-enable or remove them.

#### How the Test Works
- Identifies GPOs with GpoStatus AllDisabled and renders a detailed MD table of those GPOs.

#### Related Tests
- `Test-MtAdGpoAllSettingsDisabledDetails` is the current test; other related tests include state-wide counts.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

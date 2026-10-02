#### Test-MtAdGpoSettingsDisabledCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: checks how many GPOs have disabled settings (AllDisabled, UserDisabled, ComputerDisabled).

#### Control Type

**Operational**

#### Security Recommendation
- Review disabled settings to confirm they are intentional and document exceptions if needed.

#### How the Test Works
- Counts GPOs whose GpoStatus maps to a disabled state and reports totals and ratios.

#### Related Tests
- `Test-MtAdGpoAllSettingsDisabledDetails` and `Test-MtAdGpoSettingsDisabledCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

#### Test-MtAdGpoWmiFilterCount

 Counts the number of GPOs that have a non-empty WMI filter.

#### Why This Test Matters
- Operational control: counts GPOs that have a non-empty WMI filter to gauge policy scoping across the environment.

#### Control Type

**Operational**

#### Security Recommendation
- Review configure WMI filters to ensure correct targeting and minimize unnecessary exposure.

#### How the Test Works
- Gets GPO state, computes the number of GPOs with a non-empty WmiFilter, and reports totals and ratios.

#### Related Tests
- `Test-MtAdGpoWmiFilterDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

#### Test-MtAdGpoWmiFilterDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: detects GPOs with a non-empty WMI filter, which can influence policy scope per machine.

#### Control Type

**Operational**

#### Security Recommendation
- Review WMI-filtered GPOs to ensure filters are intentional and correctly scoped.

#### How the Test Works
- Retrieves GPO state, filters for Gpos with a non-empty WmiFilter, and renders a Markdown table with details.

#### Related Tests
- `Test-MtAdGpoWmiFilterCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

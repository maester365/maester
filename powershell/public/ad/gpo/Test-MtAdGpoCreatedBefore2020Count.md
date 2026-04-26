#### Test-MtAdGpoCreatedBefore2020Count

#### Why This Test Matters

Group Policy Objects (GPOs) created a long time ago can be a sign of policy growth over time. Older GPOs may contain outdated security settings, legacy configuration patterns, and assumptions that no longer match your current security baseline.

Tracking the count of GPOs created before 2020 helps you quickly identify areas that may benefit from review and modernization.

#### Security Recommendation

- **Review legacy GPOs regularly**: Older GPOs are more likely to include security configurations that are no longer aligned to current best practices.
- **Validate intended changes**: Before updating or removing an older GPO, validate its purpose, inheritance, and scope to avoid unintended access or availability impacts.
- **Plan for modernization**: Consolidate redundant GPOs and update policy settings to match current compliance and security requirements.

#### How the Test Works

This test retrieves GPO state from Active Directory using **Get-MtADGpoState** (it uses `$gpoState.GPOs`).

It then filters all GPOs where the `CreationTime` is earlier than **January 1st, 2020** and reports the resulting count.

#### Related Tests

- `Test-MtAdGpoTotalCount` - Total GPO inventory
- `Test-MtAdGpoUnlinkedCount` - GPOs not linked anywhere
- `Test-MtAdGpoLinkedCount` - GPOs that are actively linked

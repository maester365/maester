#### Test-MtAdGpoChangedBefore2020Count

#### Why This Test Matters

Group Policy Objects (GPOs) that have not been modified for a long time can become "stale".
Stale GPOs may contain outdated security configurations, which can create security gaps
if they no longer match your current security baselines.

#### Security Recommendation

Regularly review GPOs that have not changed recently. Consider:

- Validating that security settings are still required and aligned with your current baseline
- Removing or updating policies that are no longer used or no longer appropriate
- Establishing a review cadence for long-lived policies

#### How the Test Works

This test uses `Get-MtADGpoState` to retrieve cached GPO data.
It filters GPOs where `ModificationTime` is earlier than `2020-01-01` and calculates:

- Total number of GPOs
- Number and percentage of stale GPOs

#### Related Tests

- `Test-MtAdGpoTotalCount` - Counts the total number of GPOs

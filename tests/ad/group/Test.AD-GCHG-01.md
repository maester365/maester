Understanding the rate of group membership changes provides insights into:

- **Operational tempo**: How frequently group memberships change
- **Security monitoring**: Baseline for detecting anomalous activity
- **Compliance trends**: Track changes over time for audit purposes
- **Change management**: Identify periods of high activity
- **Lifecycle management**: Understand group creation and modification patterns

#### Control Type

**Operational**

#### Security Recommendation

Monitor group membership changes for security anomalies:
- Establish baselines for normal change rates
- Alert on changes that exceed normal thresholds
- Review spikes in activity for unauthorized changes
- Correlate group changes with change management tickets
- Implement approval workflows for privileged group changes
- Document business reasons for high-volume change periods

#### How the Test Works

This test analyzes group metadata to calculate:
- Total groups in the directory
- Timespan since oldest group was created
- Average number of group modifications per year
- Breakdown of creations and modifications by year
- Groups modified within `RecentModificationDays` (default 90)

The analysis helps identify trends and patterns in group management activity.

#### Related Tests

- **AD-GMC-02 — Distinct account types of members count should be retrievable** — `Test-MtAdGroupMemberAccountTypeCount` — Inventories member object classes, not privileged membership.
- **AD-GMC-10 — Privileged groups with members count should be investigated** — `Test-MtAdGroupPrivilegedWithMembersCount` — Reviews privileged groups.
- **AD-GMC-08 — Empty non-privileged group count should be investigated** — `Test-MtAdGroupEmptyNonPrivilegedCount` — Reviews empty non-privileged groups separately.

<!--- Results --->
%TestResult%

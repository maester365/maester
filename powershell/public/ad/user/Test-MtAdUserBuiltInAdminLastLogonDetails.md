#### Test-MtAdUserBuiltInAdminLastLogonDetails

#### Why This Test Matters

Knowing when built-in administrator style accounts last authenticated is critical for detecting stale privileged access and spotting suspicious activity.

- **Unexpected use detection**: Recent logons on sensitive accounts may warrant investigation.
- **Stale privilege cleanup**: Dormant privileged accounts should be reviewed or disabled.
- **Incident response**: Last logon data helps reconstruct privileged account activity.

#### Security Recommendation

- Investigate interactive or unexpected usage of RID 500 accounts.
- Disable or tightly restrict privileged accounts with no valid business need.
- Correlate recent logons with change windows, tickets, and admin workflows.

#### How the Test Works

This test lists built-in administrator style accounts and returns their `LastLogonDate` plus the number of days since the recorded logon.

#### Related Tests

- `Test-MtAdUserBuiltInAdminEnabledDetails`
- `Test-MtAdUserBuiltInAdminPasswordAgeDetails`

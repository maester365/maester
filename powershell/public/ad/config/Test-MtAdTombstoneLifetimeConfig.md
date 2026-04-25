# Test-MtAdTombstoneLifetimeConfig

## Why This Test Matters
The **tombstone lifetime** determines how long Active Directory retains “deleted but not yet purged” objects (for example, users, groups, and computer accounts). This directly impacts your ability to recover from:

- **Accidental deletions** performed by admins or during automation
- **Incident response actions** that remove objects and later need restoration
- **Mis-scoped deprovisioning** (bulk removals, OU moves, scripted cleanup)

If tombstone lifetime is **too short**, recovery may fail before you notice the issue. If it is **too long**, AD can accumulate a larger tombstone dataset, increasing replication/database growth and operational overhead.

## Security Recommendation
- Align tombstone lifetime with your **operational recovery window** (common baselines are ~180 days or longer, but choose based on your incident response and retention requirements).
- Document and periodically review your **maximum time-to-detect** for directory changes.
- Ensure paired recovery controls are in place (for example, **Recycle Bin** where appropriate) so deleted objects can be restored safely.

## How the Test Works
This test retrieves the environment’s configured tombstone lifetime value from AD configuration and reports it as an environment metric so you can verify it against your expected baseline.

## Related Tests
- `Test-MtAdTombstoneLifetime` - Phase 5: Reviews tombstone lifetime in the context of overall AD recovery expectations.

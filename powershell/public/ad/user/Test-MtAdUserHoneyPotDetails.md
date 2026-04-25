# Test-MtAdUserHoneyPotDetails

## Why This Test Matters

Detailed visibility into potential honey pot style users helps separate intentional deception assets from legacy, misleading, or risky accounts.

- **Deception validation**: Confirm lure accounts are intentional and monitored.
- **Operational clarity**: Distinguish test or stale accounts from active users.
- **Risk reduction**: Remove attractive-but-unnecessary account names.

## Security Recommendation

- Track owner and purpose for each identified account.
- Alert on any authentication attempts to intentional lure accounts.
- Disable or rename unnecessary accounts that imitate privileged or attractive targets.

## How the Test Works

This test returns non-system users whose names match attacker-attractive terms and includes usage-oriented details such as enabled state, last logon, and password expiry status.

## Related Tests

- `Test-MtAdUserHoneyPotCount`
- `Test-MtAdUserKnownServiceAccountDetails`

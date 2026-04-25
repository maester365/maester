# Test-MtAdUserBuiltInAdminEnabledDetails

## Why This Test Matters

Enabled built-in administrator style accounts provide immediate opportunities for misuse if their credentials are exposed. A simple inventory of active accounts in this category helps confirm whether emergency or legacy access remains enabled unnecessarily.

- **Exposure review**: Enabled privileged accounts increase attack surface.
- **Account validation**: Confirms which sensitive accounts remain active.
- **Operational control**: Supports decisions to disable or tightly restrict use.

## Security Recommendation

- Disable built-in administrator accounts when not required.
- If they must remain enabled, restrict sign-in paths and monitor all usage.
- Ensure password rotation, MFA-equivalent controls, and break-glass procedures are documented.

## How the Test Works

This test returns enabled user accounts that match the built-in administrator RID (`-500`) or are marked as critical system objects.

## Related Tests

- `Test-MtAdUserBuiltInAdminCount`
- `Test-MtAdUserBuiltInAdminLastLogonDetails`

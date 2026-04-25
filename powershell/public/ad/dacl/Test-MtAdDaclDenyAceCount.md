# Test-MtAdDaclDenyAceCount

## Why This Test Matters

Deny ACEs are powerful because they can override allow permissions and create access outcomes that are difficult to troubleshoot. Counting them provides a quick baseline for how much explicit denial logic exists in the collected AD permission set.

- **Highlights explicit deny usage** in AD DACLs
- **Supports troubleshooting** for delegation and access issues
- **Helps prioritize deeper review** when deny ACE volume is high

## Security Recommendation

Review deny ACE usage carefully. Ensure each deny entry is intentional, documented, and still required. Excessive or poorly understood deny entries can create administrative confusion and mask broader permission issues.

## How the Test Works

This test retrieves `$adState.DaclEntries`, filters entries where `AccessControlType` contains `Deny`, and reports the total deny ACE count along with the number of affected objects.

## Related Tests

- `Test-MtAdDaclDenyAceDetails`
- `Test-MtAdDaclDistinctObjectCount`
- `Test-MtAdDaclOuObjectCount`

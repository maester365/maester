Deny ACEs are powerful because they can override allow permissions and create access outcomes that are difficult to troubleshoot. Counting them provides a quick baseline for how much explicit denial logic exists in the collected AD permission set.

- **Highlights explicit deny usage** in AD DACLs
- **Supports troubleshooting** for delegation and access issues
- **Helps prioritize deeper review** when deny ACE volume is high

#### Control Type

**Operational**

#### Remediation action

Review deny ACE usage carefully. Ensure each deny entry is intentional, documented, and still required. Excessive or poorly understood deny entries can create administrative confusion and mask broader permission issues.

#### How the Test Works

This test retrieves `$adState.DaclEntries`, filters entries where `AccessControlType` is `Deny` (the collector's normalized value), reports total ACEs, deny ACEs and affected objects, and lists deny ACE counts for each object and identity. Deny ACEs are not automatically misconfigurations; review their intent.

#### Related Tests

- `Test-MtAdDaclDistinctObjectCount`
- `Test-MtAdDaclOuObjectCount`

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

Every DACL ACE references a security principal. Tracking the number of distinct identities appearing in delegated permissions helps you understand how widely access has been spread across the directory.

- **Delegation Visibility**: A large number of distinct identities can indicate broad or inconsistent delegation.
- **Review Prioritization**: Security teams can focus on identities that appear repeatedly across sensitive objects.
- **Baseline Tracking**: Repeated measurement makes it easier to spot growth in delegated access over time.

#### Control Type

**Operational**

#### Remediation action

Keep delegation models simple and intentional. Prefer group-based administration over direct assignment to many individual accounts or SIDs.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, reports total ACEs, distinct identities and objects, and lists each identity's ACE count, distinct objects, allow ACEs and deny ACEs. These are inventory metrics, not an assertion that any particular count is safe.

#### Related Tests

- `Test-MtAdDaclPrivilegedAllowAceCount`
- `Test-MtAdDaclPrivilegedExtendedRightCount`

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

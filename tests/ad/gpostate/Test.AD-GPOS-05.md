This test retrieves Active Directory GPO state data using Get-MtADGpoState and returns a markdown
table listing GPOs with GpoStatus indicating computer settings are disabled.

GpoStatus mapping:
- 0 = AllDisabled
- 1 = UserDisabled
- 2 = ComputerDisabled
- 3 = AllEnabled

#### Remediation action

Review the configuration described above.

<!--- Results --->
%TestResult%

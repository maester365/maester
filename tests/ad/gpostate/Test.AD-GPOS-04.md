This test retrieves Active Directory GPO state data using Get-MtADGpoState and counts how many
returned GPOs have GpoStatus values indicating disabled settings.

GpoStatus mapping:
- 0 = AllDisabled
- 1 = UserDisabled
- 2 = ComputerDisabled
- 3 = AllEnabled

#### Remediation action

Review the configuration described above.

<!--- Results --->
%TestResult%

Checks all collected GPOs for both Group Policy Preferences `cpassword` values and default passwords in SYSVOL security templates. Any domain user with read access to these files can recover exposed credentials. The result lists only policy names and boolean findings, never password contents. Missing scan fields and SYSVOL errors produce an error rather than a clean pass.

#### Remediation action

1. In **Group Policy Management**, locate the listed GPOs and remove password-bearing preferences or security-template settings from SYSVOL.
2. Rotate every credential that was stored in these files, including accounts with privileged access. Migrate to a supported secret-management mechanism and rescan all GPOs.

#### Related links

* [Group Policy Preferences and passwords](https://learn.microsoft.com/security-updates/securitybulletins/2014/ms14-025)

<!--- Results --->
%TestResult%

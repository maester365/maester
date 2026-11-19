Scans collected GPO files for Group Policy Preferences `cpassword` values and default passwords in preferences or security templates. Any detected secret fails the test. The summary and metrics report findings without exposing password contents; a details table names affected policies and shows finding flags only when findings exist. An incomplete scan with no findings is an error, not a clean pass; if findings exist, the test fails and reports scan incompleteness. Missing scan reports or an inventory/report count mismatch is an error.

Any domain user with read access to these files may be able to recover exposed credentials. A clean summary means no exposed passwords were found in the completed scan, not that other GPO settings are safe.

#### Remediation action

1. In **Group Policy Management**, locate listed GPOs and remove password-bearing preferences or security-template settings from SYSVOL.
2. Rotate every credential stored in these files, including credentials for privileged accounts. Move secret handling to a supported mechanism and rescan all GPOs.

#### Related links

* [Group Policy Preferences and passwords](https://learn.microsoft.com/security-updates/securitybulletins/2014/ms14-025)

<!--- Results --->
%TestResult%

Checks all collected GPOs for both Group Policy Preferences `cpassword` values and default passwords in SYSVOL security templates. Any domain user with read access to these files can recover exposed credentials. The result lists only policy names and boolean findings, never password contents. Missing scan fields and SYSVOL errors produce an error rather than a clean pass.

#### Why This Test Matters

Group Policy Preferences cpassword values can expose recoverable credentials to readers of SYSVOL. The merged check also detects clear-text default-password settings, but never prints the credential values.

#### Control Type

**Detective**

#### Security Recommendation

Remove exposed settings and rotate their associated credentials; treat every affected policy as a credential exposure, not simply a configuration tidy-up.

#### How the Test Works

The collected GPO state is examined for `cpassword` and default-password indicators across all policies. The check reports affected policies and counts without ever reproducing a secret. Missing or incomplete scan results do not pass.

#### Related Tests

- **AD-GPOREP-15 — GPO directory and SYSVOL versions should match** — `Test-MtAdGpoVersionMismatchCount` — Reviews policy file and directory version consistency.

#### Remediation action

1. In **Group Policy Management**, locate the listed GPOs and remove password-bearing preferences or security-template settings from SYSVOL.
2. Rotate every credential that was stored in these files, including accounts with privileged access. Migrate to a supported secret-management mechanism and rescan all GPOs.

#### Related links

* [Group Policy Preferences and passwords](https://learn.microsoft.com/security-updates/securitybulletins/2014/ms14-025)

<!--- Results --->
%TestResult%

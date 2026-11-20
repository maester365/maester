Scans collected GPO files for Group Policy Preferences `cpassword` values and
default passwords in preferences or security templates. Any detected secret fails
the test. The read-only scan reports presence without exposing credential values;
it does not remove secrets or rotate credentials.

#### Control Type

**Detective**

#### Why This Test Matters

The `cpassword` value is recoverable, and Microsoft notes that any authenticated
user can retrieve and decrypt passwords stored in Group Policy Preferences. Other
detected default passwords also represent exposed credentials. Treat findings as
critical and rotate affected credentials, including privileged ones; deleting a
stored value alone does not invalidate a credential that may already be known.

#### Security Recommendation

Remove password-bearing settings from GPO files and rotate every affected
credential. Use a supported secret-management mechanism instead of storing
passwords in preferences or security templates. Applying the MS14-025 update does
not remove legacy `cpassword` values already stored in SYSVOL.

#### How the Test Works

- Scans collected GPO files for `cpassword` and default-password indicators in
  preferences or security templates.
- Either finding type on a policy is enough to fail the test. A policy is counted
  once even if both indicators are present; details show flags, not secret values.
- An incomplete scan with no findings is an error, not a clean pass. If findings
  exist, the test fails and reports scan incompleteness. Missing reports, an
  empty report set, or an inventory/report count mismatch is an error.
- A clean result means no such passwords were found in the completed scan; it
  does not certify other GPO settings.

#### Remediation action

1. In **Group Policy Management**, locate each listed GPO and remove
   password-bearing preferences or security-template settings from SYSVOL.
2. Rotate every credential stored there, including credentials for privileged
   accounts. Then move secret handling to a supported mechanism and rescan all
   GPOs; do not rely on removing the XML value alone.

#### Related Tests

- [AD-GPOREP-01 — No GPO should have an empty permissions list](https://maester.dev/docs/tests/AD-GPOREP-01) (`Test-MtAdGpoNoPermissionsCount`) assesses whether GPO permission entries are present; it does not determine which users can effectively read a secret-bearing file.

#### Related links

- [Group Policy Preferences and passwords (MS14-025)](https://learn.microsoft.com/security-updates/securitybulletins/2014/ms14-025)
- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

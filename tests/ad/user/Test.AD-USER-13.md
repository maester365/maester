Unapproved SID history can retain access granted to older identities after migrations. Migration exceptions must be documented and passed in `ApprovedAccountIds`.

#### Control Type

**Detective**

#### Security Recommendation

Confirm migration and access dependencies before clearing SID history; review documented exceptions periodically.

#### How the Test Works

The test checks users with `SIDHistory` values and excludes explicitly approved account IDs. A populated history warrants review but does not by itself prove misuse.

#### Related Tests

- **AD-USER-12 — Ordinary users should use an approved primary group** — `Test-MtAdUserNonStandardPrimaryGroupCount` — Reviews primary-group configuration.
- **AD-USER-11 — AdminCount users should be reviewed** — `Test-MtAdUserAdminCountCount` — Helps prioritize protected identities.

#### Remediation action
1. Validate each migration dependency and resource ACL before removing [SID history](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).
2. Review exceptions periodically and remove unnecessary history under a change plan.

<!--- Results --->
%TestResult%

Unapproved SID history can retain access granted to older identities after migrations. Migration exceptions must be documented and passed in `ApprovedAccountIds`.

#### Remediation action
1. Validate each migration dependency and resource ACL before removing [SID history](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).
2. Review exceptions periodically and remove unnecessary history under a change plan.

<!--- Results --->
%TestResult%

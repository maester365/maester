The domain SID plus RID 500 identifies the built-in administrator, regardless of renaming. This check evaluates its disabled state, recent recorded logon (configurable minimum 30 idle days) and password age (configurable maximum 180 days). Replicated logon timestamps can lag; the configurable `MaximumLogonTimestampLagDays` defaults to 14. Recorded idle ages from 30 through 43 days require investigation rather than a clean pass. This is not an exact all-domain-controller last-logon audit. Other critical system objects are **not** RID-500 accounts.

#### Control Type

**Operational**

#### Security Recommendation

Protect the RID-500 built-in administrator with controlled emergency access, credential rotation and monitored use. Corroborate replicated logon timestamps before acting on apparent inactivity.

#### How the Test Works

The test resolves the domain SID plus RID 500 and checks its disabled state, recorded logon age against the configured minimum and password age against the configured maximum. `MaximumLogonTimestampLagDays` (default 14) creates an investigation band around the idle cutoff; the result is not an exact per-DC last-logon audit.

#### Related Tests

- **AD-USER-11 — AdminCount users should be reviewed** — `Test-MtAdUserAdminCountCount` — Reviews protected users, not a substitute for RID-500 identification.

#### Remediation action
1. Validate emergency access before changing [the built-in administrator](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).
2. Corroborate usage with DC logon events and rotate old credentials under break-glass procedures; restrict or disable unused access when appropriate.

<!--- Results --->
%TestResult%

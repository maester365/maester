Checks that each Group Policy Object (GPO) has been modified within the configured age limit, **five calendar years** by default.

The last modification date drives pass/fail; creation and modification dates are shown together for every policy. A policy created many years ago but modified recently passes. Age is a hygiene indicator, not proof that a policy is insecure, and changing a timestamp alone is not a security review.

#### Control Type

**Detective**

#### Security Recommendation

Review policies whose modification date is older than the organization's review interval; validate scope, inheritance and dependencies before modifying or retiring a GPO.

#### Remediation action

1. In **Group Policy Management**, review each stale policy with its owner against the current baseline, intended scope and dependencies.
2. Update settings that are no longer appropriate, test with a pilot group and retain a backup before deployment. Archive or remove redundant policies only after verifying they are unused.
3. If your organization uses a different review interval, set `MaximumAgeYears` under this test's `TestSettings[].Parameters` in `maester-config.json`.

#### How the Test Works

This test uses the cached `Get-MtADGpoState` inventory. It fails if any `ModificationTime` is earlier than the run's current date minus `MaximumAgeYears` (default five calendar years); the creation date is shown for review but does not drive the verdict. Missing inventory or modification dates produce Error rather than a clean pass. The cutoff is exclusive: a date exactly at the cutoff is within the limit.

#### Related Tests

- **AD-GPO-01 — GPO inventory should be investigated** — `Test-MtAdGpoTotalCount` — Inventories GPOs separately.
- **AD-GPO-04 — GPOs should have at least one link** — `Test-MtAdGpoUnlinkedCount` — Identifies GPOs with no links.

<!--- Results --->
%TestResult%

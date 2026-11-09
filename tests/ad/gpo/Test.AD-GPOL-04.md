Enforced Group Policy Object (GPO) links **override blocked inheritance** in descendant containers. Enforcement and inheritance blocking are different settings; an enforced link does not itself block inheritance.

This can be a powerful mechanism for security baselines, but it also increases the chance that a critical policy unintentionally becomes “sticky” across the domain.

#### Control Type

**Detective**

#### Security Recommendation

- **Enforced GPOs override inheritance blocking**: any configuration enforced at a higher scope can still apply even if child OUs attempt to disable inheritance.
- **Use enforced links sparingly**: reserve them for critical security policies that must apply everywhere.
- **Review enforced policies regularly**: confirm the GPO’s purpose and ownership, and ensure the enforced settings remain aligned with current security requirements.

#### How the Test Works

This test retrieves Active Directory GPO state from `Get-MtADGpoState` (using `$gpoState.GPOLinks`) and:

1. Examines each collected link object for the `Enforced` property.
2. Counts link entries where `Enforced` is `$true`.
3. Reports the enforced link count and the enforced ratio in Markdown.

The result is **Investigate**, whether or not enforced links exist. Missing link inventory produces Error, not a zero count or clean baseline.

#### Remediation action

In Group Policy Management, review the scope and ownership of each enforced link against the intended baseline. Retain intentional enforcement; validate effective user and computer policy before changing it.

#### Related Tests

- **AD-GPO-01 — GPO inventory should be investigated** — `Test-MtAdGpoTotalCount` — Inventories all GPOs.
- **AD-GPOL-01 — GPO linked count should be investigated** — `Test-MtAdGpoLinkedCount` — Inventories linked GPOs.
- **AD-GPO-04 — GPOs should have at least one link** — `Test-MtAdGpoUnlinkedCount` — Identifies unlinked GPOs.

<!--- Results --->
%TestResult%

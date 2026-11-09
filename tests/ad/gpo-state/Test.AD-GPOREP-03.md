Inventories GPOs without an Authenticated Users allow entry. An alternative security-filtering group may be intentional; a missing entry alone does not prove the GPO is insecure. Unreadable permissions are reported separately.

#### Why This Test Matters

Absence of Authenticated Users may be intentional security filtering. Review whether intended user and computer recipients retain the necessary permissions; absence alone does not prove widened access or a policy gap.

#### Control Type

**Detective**

#### Security Recommendation

Validate each affected policy's intended security filter and ensure computer accounts can read a user policy where required; do not add Authenticated Users without checking scope.

#### How the Test Works

The check counts GPO reports whose `HasAuthenticatedUsers` is false. Unreadable security descriptors are reported separately as not evaluated rather than as missing entries or clean policies.

#### Related Tests

- **AD-GPOREP-06 — GPOs without domain computers count should be retrievable** — `Test-MtAdGpoNoDomainComputersCount` — Inventories GPOs without domain computers.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** > **Security Filtering** and **Delegation** settings.
2. Confirm that intended users or computers can read and apply the GPO; add an appropriate allow entry only when necessary. Investigate permissions that could not be evaluated.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%

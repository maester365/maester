User accounts trusted for unconstrained delegation can expose tickets and support lateral movement after compromise. This check fails on the unconstrained flag and separately reports constrained, protocol-transition and resource-based delegation indicators for human review; protocol transition alone does not establish a valid constrained target. AD-USER-28 and AD-USER-29 were consolidated here.

#### Control Type

**Detective**

#### Security Recommendation

Remove unconstrained delegation from user accounts after reviewing service dependencies; use scoped delegation where needed, and verify permitted targets.

#### How the Test Works

The test fails on unconstrained delegation and separately inventories constrained, protocol-transition and resource-based indicators. Protocol transition by itself does not establish a valid target; the inventory is not proof of effective delegated access.

#### Related Tests

- **AD-USER-07 — All users should require Kerberos pre-authentication** — `Test-MtAdUserNoPreAuthCount` — Reviews another Kerberos exposure on users.

#### Remediation action
1. Review delegated users and their service dependencies using [Microsoft delegation guidance](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-constrained-delegation-overview).
2. Remove unconstrained delegation, migrate to scoped delegation or managed identities and review all allowed targets.

<!--- Results --->
%TestResult%

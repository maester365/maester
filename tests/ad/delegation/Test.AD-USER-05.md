User accounts trusted for unconstrained delegation can expose tickets and support lateral movement after compromise. This check fails on the unconstrained flag and separately reports constrained, protocol-transition and resource-based delegation indicators for human review; protocol transition alone does not establish a valid constrained target. AD-USER-28 and AD-USER-29 were consolidated here.

#### Remediation action
1. Review delegated users and their service dependencies using [Microsoft delegation guidance](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-constrained-delegation-overview).
2. Remove unconstrained delegation, migrate to scoped delegation or managed identities and review all allowed targets.

<!--- Results --->
%TestResult%

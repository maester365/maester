Checks that `ms-DS-MachineAccountQuota` is zero in the connected domain. The default quota of 10 permits ordinary users to create computer accounts; restricting that path reduces opportunities to establish attacker-controlled domain identities.

#### Remediation action

1. Identify legitimate domain-join workflows and delegate narrowly scoped computer-creation rights to approved provisioning identities.
2. With an authorized administrator, set the domain attribute to zero, for example: `Set-ADDomain -Identity <domain> -Replace @{'ms-DS-MachineAccountQuota' = 0}`.
3. Pilot the join workflow and confirm the configured value. Missing attribute data produces Error, not an assumed default. The reported default comparison is a value comparison, not evidence that the value was never configured.

#### Related links

* [Microsoft Defender for Identity: Prevent non-privileged users from registering computers](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/allow-non-admins-register-computers)

<!--- Results --->
%TestResult%

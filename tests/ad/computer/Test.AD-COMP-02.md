Dormant (stale) computer accounts—enabled accounts that haven't authenticated for more than the configured threshold (default 90 days)—pose significant security risks:

- **Attack vector**: Attackers can exploit dormant accounts that may have weak or unchanged passwords
- **Shadow IT**: These may represent forgotten test systems, VMs, or decommissioned hardware still in the directory
- **Lateral movement**: Compromised dormant accounts can be used to move laterally within the network
- **Compliance issues**: Many security frameworks require identification and remediation of stale accounts

#### Control Type

**Detective**

#### Security Recommendation

Establish a process to:
1. Identify dormant computers (this test)
2. Investigate whether they represent legitimate systems
3. Disable accounts for systems that are truly decommissioned
4. Delete disabled accounts after a verification period

#### How the Test Works

This test examines all enabled computer accounts and identifies those where:
- The `lastLogonDate` property is older than `DormantThresholdDays` (default 90 days)
- The account remains enabled

The default 90-day threshold is a common security baseline. Set `DormantThresholdDays` to adjust it based on your organization's requirements (e.g., seasonal systems, remote workstations).

#### Related Tests

- `Test-MtAdComputerDisabledCount` - Counts already-disabled computer accounts
- `Test-MtAdComputerInDefaultContainer` - Identifies computers that may be unmanaged

<!--- Results --->
%TestResult%

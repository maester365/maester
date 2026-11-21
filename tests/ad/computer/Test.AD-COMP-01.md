Disabled computer accounts that remain in Active Directory represent a security hygiene issue. While disabling a computer account is a valid administrative action (typically when decommissioning systems), these accounts should eventually be removed to:

- **Reduce attack surface**: Disabled accounts can be re-enabled by attackers who gain privileged access
- **Prevent confusion**: Distinguish between active and truly decommissioned systems
- **Maintain directory cleanliness**: Simplify auditing and compliance reporting
- **Avoid stale data**: Ensure Group Policy and software deployment targets are accurate

#### Control Type

**Detective**

#### Security Recommendation

Regularly review disabled computer accounts and delete those that are permanently decommissioned. Consider establishing a process where disabled computers are automatically deleted after a defined retention period (e.g., 30-90 days).

#### How the Test Works

This test retrieves all computer objects from Active Directory and counts:
- Total number of computer accounts
- Number of disabled computer accounts
- Percentage of computers that are disabled

The test returns informational results to help you assess the scope of disabled accounts in your environment.

#### Related Tests

- [AD-DCOMP-06 — No enabled computers should be stale beyond the configured threshold](https://maester.dev/docs/tests/AD-DCOMP-06): Complements this disabled-account count by identifying enabled computer accounts that have not logged on recently.
- [AD-COMP-06 — Enabled computers should be moved out of the default Computers container](https://maester.dev/docs/tests/AD-COMP-06): Adds context on computer-account hygiene by identifying enabled computers left in the default container.

<!--- Results --->
%TestResult%

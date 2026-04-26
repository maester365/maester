#### Test-MtAdComputerDisabledCount

#### Why This Test Matters

Disabled computer accounts that remain in Active Directory represent a security hygiene issue. While disabling a computer account is a valid administrative action (typically when decommissioning systems), these accounts should eventually be removed to:

- **Reduce attack surface**: Disabled accounts can be re-enabled by attackers who gain privileged access
- **Prevent confusion**: Distinguish between active and truly decommissioned systems
- **Maintain directory cleanliness**: Simplify auditing and compliance reporting
- **Avoid stale data**: Ensure Group Policy and software deployment targets are accurate

#### Security Recommendation

Regularly review disabled computer accounts and delete those that are permanently decommissioned. Consider establishing a process where disabled computers are automatically deleted after a defined retention period (e.g., 30-90 days).

#### How the Test Works

This test retrieves all computer objects from Active Directory and counts:
- Total number of computer accounts
- Number of disabled computer accounts
- Percentage of computers that are disabled

The test returns informational results to help you assess the scope of disabled accounts in your environment.

#### Related Tests

- `Test-MtAdComputerDormantCount` - Identifies enabled computers that haven't logged on recently
- `Test-MtAdComputerInDefaultContainer` - Finds computers in the default container (another hygiene indicator)

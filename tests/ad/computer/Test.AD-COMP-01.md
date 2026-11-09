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

This cached investigation inventory counts visible computer objects and reports:
- Total number of computer accounts
- Known-enabled and known-disabled computer accounts separately
- Accounts whose enabled state is unknown
- Known-disabled share of the visible inventory, which may undercount disabled objects when some statuses are unknown
- Each known-disabled computer and its distinguished name

The result is **Investigate**, not a zero-disabled-computer pass/fail baseline. Unknown statuses are reported rather than silently classified as enabled or aborting the entire inventory. A missing whole computer collection remains Error. Removing disabled accounts requires owner approval and a suitable retention policy; presence alone is not evidence of an active compromise.

#### Related Tests

- **AD-COMP-06 — Enabled computers should be moved out of the default Computers container** — `Test-MtAdComputerInDefaultContainer` — Reviews default-container placement independently of account status.

<!--- Results --->
%TestResult%

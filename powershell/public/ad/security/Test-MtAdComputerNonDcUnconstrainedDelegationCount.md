#### Test-MtAdComputerNonDcUnconstrainedDelegationCount

#### Why This Test Matters

- Non-domain controller computers with unconstrained delegation represent a **CRITICAL** security vulnerability. While domain controllers may have legitimate reasons for unconstrained delegation in certain legacy scenarios, regular computers should **NEVER** have this configuration.

**Critical Security Risks:**
- **Domain Compromise**: A single compromised computer with unconstrained delegation can lead to full domain compromise
- **Unrestricted Impersonation**: Any service on the computer can impersonate any domain user to any service
- **Attack Vector**: Common target for attackers seeking to escalate privileges
- **Stealthy Access**: Can be exploited without triggering typical security alerts

**The target count for this test should ALWAYS be ZERO.**

#### Security Recommendation

1. **Immediate Action Required**:
   - Identify all non-DC computers with unconstrained delegation
   - Remove unconstrained delegation immediately
   - Investigate why it was configured

2. **Replace with secure alternatives**:
   - **Constrained Delegation**: Limit to specific required services
   - **Resource-Based Constrained Delegation**: Modern, flexible approach
   - **Managed Service Accounts**: Use gMSAs where possible

3. **Audit and Monitor**:
   - Regular audits of delegation settings
   - Alert on any new unconstrained delegation configurations
   - Review applications requiring delegation

#### How the Test Works

This test specifically identifies non-DC computers with the `TrustedForDelegation` flag enabled and reports:
- Count of affected computers
- Computer names and operating systems
- Compliance status (should be zero)

**Pass Criteria**: Zero non-DC computers with unconstrained delegation

#### Related Tests

- `Test-MtAdComputerUnconstrainedDelegationCount` - Overall unconstrained delegation count
- `Test-MtAdComputerNonDcConstrainedDelegationCount` - Reviews constrained delegation on non-DCs
- `Test-MtAdComputerDelegationCount` - General delegation overview

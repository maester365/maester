#### Test-MtAdComputerUnconstrainedDelegationCount

#### Why This Test Matters

- Unconstrained delegation is one of the most dangerous configurations in Active Directory. When enabled on a computer, it allows services on that computer to impersonate authenticated users to ANY service on ANY computer in the domain.

**Security Risks:**
- **Complete Impersonation**: Attackers can impersonate any user who authenticates to the computer
- **Lateral Movement**: Compromising one computer with unconstrained delegation enables access to all domain resources
- **Privilege Escalation**: Can be used to escalate from standard user to domain admin
- **Ticket Theft**: Attackers can harvest TGTs from memory on these computers

#### Security Recommendation

1. **Eliminate unconstrained delegation**:
   - Replace with constrained delegation or resource-based constrained delegation
   - Audit all computers with this setting
   - Prioritize non-DC computers for remediation

2. **Protect computers that require delegation**:
   - Limit to absolute minimum necessary
   - Place in isolated OU with strict access controls
   - Monitor for compromise indicators

3. **Use alternatives**:
   - **Constrained Delegation**: Limits impersonation to specific services
   - **Resource-Based Constrained Delegation**: More flexible and secure approach
   - **Protocol Transition**: When combined with constrained delegation

#### How the Test Works

This test counts computers with the `TrustedForDelegation` flag enabled and categorizes them by:
- Domain Controllers vs. non-DC computers
- Total count and percentage

#### Related Tests

- `Test-MtAdComputerNonDcUnconstrainedDelegationCount` - Focuses on non-DC computers (critical risk)
- `Test-MtAdComputerNonDcConstrainedDelegationCount` - Reviews constrained delegation
- `Test-MtAdUserDelegationConfiguredCount` - Reviews user account delegation

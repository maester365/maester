# Test-MtAdComputerNonDcConstrainedDelegationCount

## Why This Test Matters

Constrained delegation (also known as "protocol transition" or S4U2Proxy) is safer than unconstrained delegation but still carries security risks. It allows a service to impersonate a user to specific services only, rather than any service in the domain.

**Security Considerations:**
- **Limited Scope**: Safer than unconstrained but still enables impersonation
- **Configuration Complexity**: Easy to misconfigure and accidentally grant excessive permissions
- **Attack Surface**: Each computer with constrained delegation expands the attack surface
- **Legacy Protocol**: Some implementations may fall back to less secure methods

## Security Recommendation

1. **Minimize Usage**:
   - Use only where absolutely necessary
   - Regular review of all constrained delegation configurations
   - Document business justification for each instance

2. **Secure Configuration**:
   - Limit to specific SPNs (Service Principal Names)
   - Use protocol transition only when required
   - Regular auditing of delegation settings

3. **Consider Modern Alternatives**:
   - **Resource-Based Constrained Delegation**: More flexible and easier to manage
   - **Group Managed Service Accounts (gMSA)**: Automatic password management
   - **Managed Identity**: For cloud and hybrid scenarios

## How the Test Works

This test counts non-DC computers with the `TrustedToAuthForDelegation` flag enabled, which indicates:
- Constrained delegation is configured
- Protocol transition may be enabled

## Related Tests

- `Test-MtAdComputerUnconstrainedDelegationCount` - Overall unconstrained delegation
- `Test-MtAdComputerNonDcUnconstrainedDelegationCount` - Critical non-DC unconstrained delegation
- `Test-MtAdUserDelegationConfiguredCount` - User account delegation settings

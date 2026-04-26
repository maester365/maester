#### Test-MtAdComputerDelegationCount

#### Why This Test Matters

Kerberos delegation allows a service to impersonate users when accessing other resources. While necessary for some applications, delegation—especially unconstrained delegation—creates significant security risks:

- **Unconstrained delegation**: The service can impersonate users to ANY service on ANY system (highest risk)
- **Constrained delegation**: Limited to specific services, but still requires careful management
- **Protocol transition**: Allows S4U2Self/S4U2Proxy operations that can be exploited
- **Lateral movement**: Attackers can abuse delegation for privilege escalation and lateral movement

#### Security Recommendation

- **Minimize unconstrained delegation**: Use it only when absolutely necessary, and never on tier 0 systems
- **Prefer constrained delegation**: Limit services to only those they need to access
- **Use resource-based constrained delegation**: More secure alternative in modern environments
- **Regular audits**: Periodically review which computers have delegation enabled
- **Remove unused delegation**: Disable delegation on systems that no longer require it
- **Consider Group Managed Service Accounts (gMSA)**: These provide better security for service accounts

#### How the Test Works

This test counts computers with different delegation configurations:
- `TrustedForDelegation` (unconstrained delegation)
- `TrustedToAuthForDelegation` (constrained delegation with protocol transition)

#### Related Tests

- `Test-MtAdComputerDelegationDetails` - Provides detailed breakdown of delegation per computer
- `Test-MtAdComputerDormantCount` - Identifies stale accounts that may have delegation enabled

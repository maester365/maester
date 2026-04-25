# Test-MtAdDomainFunctionalLevel

## Why This Test Matters

The domain functional level determines which Active Directory features are available in your domain. Higher functional levels unlock important security capabilities:

- **Windows Server 2016+**: Enables features like privileged access management (PAM), temporary group membership, and enhanced authentication policies
- **Windows Server 2012 R2+**: Provides access to claims-based authentication and compound authentication
- **Security Posture**: Running at lower functional levels means missing modern security features that protect against contemporary attack vectors

## Security Recommendation

Aim to maintain your domain at the highest functional level supported by your domain controllers. Before raising the functional level:

1. Verify all domain controllers are running a Windows Server version that supports the target level
2. Test applications for compatibility with the higher functional level
3. Plan the upgrade during a maintenance window
4. Document the change and communicate to stakeholders

## How the Test Works

This test retrieves the current domain functional level from Active Directory and displays it along with basic domain information. The test is informational and helps you understand your current security capabilities.

## Related Tests

- `Test-MtAdForestFunctionalLevel` - Retrieves the forest functional level
- `Test-MtAdDomainControllerCount` - Counts domain controllers in the domain

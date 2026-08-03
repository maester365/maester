#### Test-MtAdOptionalFeatureCount

#### Why This Test Matters

Active Directory optional features extend the base functionality of AD and can significantly impact security capabilities:

- **Recycle Bin**: Critical for recovering accidentally or maliciously deleted objects
- **Privileged Access Management (PAM)**: Enables time-based group membership for just-in-time access
- **Feature Awareness**: Understanding available features helps assess security posture

Knowing which optional features are available helps administrators understand the full capabilities of their Active Directory environment and identify opportunities to enhance security.

#### Security Recommendation

- Enable the Active Directory Recycle Bin if not already enabled
- Consider PAM for privileged access scenarios
- Regularly review available optional features
- Keep domain and forest functional levels current to access newer features
- Document enabled optional features and their configuration

#### How the Test Works

This test retrieves all Active Directory optional features and counts:
- Total number of optional features available
- List of feature names

#### Related Tests

- `Test-MtAdOptionalFeatureEnabledDetails` - Provides detailed information about enabled features
- `Test-MtAdRecycleBinStatus` - Checks if the Recycle Bin is enabled

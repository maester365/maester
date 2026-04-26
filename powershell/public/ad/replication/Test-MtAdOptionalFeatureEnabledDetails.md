#### Test-MtAdOptionalFeatureEnabledDetails

#### Why This Test Matters

Understanding which Active Directory optional features are enabled and their scope is crucial for security management:

- **Recycle Bin**: Should be enabled at the forest level for object recovery capabilities
- **Privileged Access Management**: May be enabled for specific domains or the entire forest
- **Feature Scope**: Knowing where features are enabled helps ensure consistent security policies

Enabled optional features represent additional capabilities that can enhance security but also increase the attack surface if not properly managed.

#### Security Recommendation

- Enable Recycle Bin at the forest level if not already enabled
- Document all enabled optional features and their scope
- Regularly review enabled features to ensure they align with security requirements
- Understand the implications of each enabled feature
- Monitor for unauthorized enabling of optional features

#### How the Test Works

This test retrieves detailed information about enabled optional features:
- Total optional features available
- Number of features with enabled scopes
- Feature names and their enabled scope counts
- Detailed breakdown of each enabled feature

#### Related Tests

- `Test-MtAdOptionalFeatureCount` - Counts total available optional features
- `Test-MtAdRecycleBinStatus` - Specifically checks Recycle Bin status

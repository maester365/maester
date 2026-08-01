#### Test-MtAdOptionalFeaturesCount

#### Why This Test Matters
Active Directory **optional features** (and related feature flags) enable or enhance behaviors such as recoverability and directory management capabilities. Incorrectly enabled/disabled features can materially affect your security posture by:

- Reducing your ability to recover from accidental or malicious deletion
- Leaving legacy behaviors in place longer than necessary
- Causing operational drift that attackers can exploit via misconfiguration

In particular, features that improve recovery (such as those related to the Recycle Bin) directly impact resilience during incidents.

#### Security Recommendation
- Ensure critical recoverability features (notably **Recycle Bin**) are enabled for the partitions that contain important identity data.
- Treat optional feature changes as **security configuration changes**: use a change control process, test first, and validate after enabling/disabling.
- Keep optional feature configuration consistent across domains/partitions where required.

#### How the Test Works
This test retrieves the set of enabled AD optional feature flags and reports them as a count/visibility metric so administrators can confirm whether the expected security-enhancing features are active.

#### Related Tests
- `Test-MtAdRecycleBinEnabledPaths` - Shows where Recycle Bin is enabled.
- `Test-MtAdRecycleBinStatus` - Validates the Recycle Bin state.

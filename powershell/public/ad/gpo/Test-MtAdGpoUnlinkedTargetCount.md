#### Test-MtAdGpoUnlinkedTargetCount

#### Why This Test Matters

Active Directory targets (OUs, the domain root, and sites) without any Group Policy links may indicate incomplete security policy coverage.

When a target has no GPO links, security and configuration baselines may not be applied consistently—creating gaps that attackers or misconfigurations can exploit.

#### Security Recommendation

Investigate any unlinked targets and remediate the policy coverage gap:

- Confirm the target should receive baseline policies (security requirements, ownership, and intended design).
- Add the appropriate GPO links (typically security baselines and auditing policies) to restore consistent enforcement.
- Review GPO inheritance/blocking design to ensure links are not unintentionally prevented.
- Maintain a deployment cadence so new OUs/domains/sites do not remain unlinked.

Unlinked targets can represent missing or outdated configurations, so treat results as potential security configuration gaps.

#### How the Test Works

This test uses `Get-MtADGpoState` (and its cached `GPOLinks`/AD data) and:

1. Enumerates all OUs using `Get-ADOrganizationalUnit`.
2. Reads the `gPLink` value for the domain root.
3. Identifies site link objects from `Get-MtADGpoState` (`$gpoState.SiteContainers`).
4. Counts each target whose `gPLink` value contains no GPO GUID references (i.e., no GPO links).

#### Related Tests

- `Test-MtAdGpoUnlinkedCount` - Identifies GPOs that are not linked to any location
- `Test-MtAdGpoLinkedCount` - Counts distinct GPOs that are actively linked
- `Test-MtAdGpoUnlinkedDetails` - Returns details of unlinked GPOs
- `Test-MtAdGpoLinkedOUCount` - (if implemented) OUs with GPO links

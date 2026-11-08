Reports direct Group Policy links on OUs, domain roots and sites for **Investigate**, including counts of linked and unlinked OUs and details of targets without direct links.

An OU can inherit policy from its parent or domain without a direct link. A direct link also does not prove that a policy applies: link status, inheritance, security filtering and WMI filtering affect the effective result. This inventory therefore does not pass or fail a security baseline.

#### Control Type

**Operational**

#### Remediation action

In **Group Policy Management**, review targets without direct links:

- Confirm the target should receive baseline policies (security requirements, ownership, and intended design).
- Add the appropriate GPO links (typically security baselines and auditing policies) to restore consistent enforcement.
- Review GPO inheritance/blocking design to ensure links are not unintentionally prevented.
- Maintain a deployment cadence so new OUs/domains/sites do not remain unlinked.

Use Group Policy Results or Modeling to verify effective policy before adding links.

#### How the Test Works

This test uses `Get-MtADGpoState` (and its cached `GPOLinks`/AD data) and:

1. Enumerates OU and domain containers from cached LDAP data.
2. Reads the `gPLink` value for the domain root.
3. Identifies site objects from `Get-MtADGpoState` (`$gpoState.SiteContainers`).
4. Counts each target whose `gPLink` value contains no GPO GUID references (i.e., no GPO links).

#### Related Tests

- `Test-MtAdGpoUnlinkedCount` - Identifies GPOs that are not linked to any location
- `Test-MtAdGpoLinkedCount` - Counts distinct GPOs that are actively linked
- `AD-GPO-04` - Returns counts and details of unlinked GPOs

<!--- Results --->
%TestResult%

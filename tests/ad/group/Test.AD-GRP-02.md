Active Directory groups can be located under an Organizational Unit (OU) or a container. OUs can support delegated administration and logical organization. Group Policy links target sites, domains and OUs—not group objects. Group membership may be used for GPO security filtering, but that does not make a group object a GPO target.

Moving groups into an OU may make delegated administration and organization easier, but does not change where Group Policy is applied to user and computer accounts.

#### Control Type

**Operational**

#### Security Recommendation

- Review group locations against the organization's administrative delegation and organization model.
- Move groups only when an OU better supports delegated administration or organization; confirm permissions and dependencies first.
- Do not move group objects to change GPO scope. Group Policy links apply to sites, domains and OUs; groups may instead be used for security filtering.
- Review unexpected changes to group locations with the group owner.

#### How the Test Works

The test removes the group's own relative distinguished-name component, respecting escaped commas, then classifies its immediate parent as `CN=`, `OU=` or another naming component. It reports container, OU and other-parent counts without treating the group's own `CN=` as its location. This is an organizational inventory, not an assessment of GPO scope or application.

#### Related Tests

- **AD-GRP-04 — Groups with manager count should be retrievable** — `Test-MtAdGroupWithManagerCount` — Inventories the `ManagedBy` attribute for ownership review.
- **AD-GRP-03 — Groups should be modified within the configured age** — `Test-MtAdGroupStaleCount` — Flags groups for lifecycle review; modification age alone does not establish use.

#### Related links

- [Microsoft: Group Policy scope](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-scope)
- [Microsoft: Delegate administration of default containers and OUs](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/delegating-administration-of-default-containers-and-ous)

<!--- Results --->
%TestResult%

#### Test-MtAdGpoUnlinkedDetails

#### Why This Test Matters

Unlinked Group Policy Objects (GPOs) are policies that exist in Active Directory but are not linked to any
site, domain, or organizational unit (OU). Even when unlinked, these GPOs still represent configuration
artifacts that can create operational overhead and increase risk.

- **Security risk**: Unused policies may still contain insecure settings that could be re-enabled accidentally.
- **Operational complexity**: GPO sprawl makes it harder to reason about what policies actually apply.
- **Maintenance hygiene**: Tracking unlinked GPOs supports safe cleanup and ongoing policy governance.

#### Security Recommendation

Review the returned unlinked GPOs and consider removing those that are no longer needed.

This reduces the attack surface by removing unused policies that could be re-linked or misconfigured
in the future.

#### How the Test Works

This test uses `Get-MtADGpoState` to retrieve cached GPO data (`$gpoState.GPOs`). It then identifies unlinked
GPOs and generates a markdown table containing:

- **GPO DisplayName**
- **CreationTime**
- **ModificationTime**

The table is intended to support quick review during GPO cleanup and maintenance activities.

#### Related Tests

- `Test-MtAdGpoUnlinkedCount` - Identifies how many GPOs are not linked to any location
- `Test-MtAdGpoLinkedCount` - Counts GPOs that are actively linked
- `Test-MtAdGpoTotalCount` - Counts the total number of GPOs in the domain

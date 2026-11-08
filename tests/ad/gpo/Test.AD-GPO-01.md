Understanding the total number of Group Policy Objects (GPOs) in your Active Directory environment is crucial for several security and operational reasons:

- **Policy Sprawl**: A large number of GPOs can indicate policy sprawl, making it difficult to manage and troubleshoot policy conflicts
- **Performance Impact**: Each GPO adds processing overhead during user logon and computer startup
- **Security Complexity**: More GPOs mean more potential attack surfaces if any contain misconfigurations
- **Audit Requirements**: Compliance frameworks often require understanding of policy scope and distribution

#### Control Type

**Operational**

#### Security Recommendation

Regularly audit your GPO inventory and consolidate redundant or overlapping policies. Consider:

- Merging GPOs with similar settings
- Removing unused or obsolete GPOs
- Documenting the purpose of each GPO
- Implementing a naming convention for better organization

#### How the Test Works

This test retrieves all Group Policy Objects from Active Directory and counts the total number. It uses the Get-MtADGpoState function to access cached GPO data.

#### Related Tests

- **AD-GPO-04 — GPOs should have at least one link** — `Test-MtAdGpoUnlinkedCount` — Identifies GPOs with no links.
- **AD-GPO-02 — GPOs should be modified within the configured age limit** — `Test-MtAdGpoStale` — Replaces the retired created-before-2020 count.
- **AD-GPOL-01 — GPO linked count should be investigated** — `Test-MtAdGpoLinkedCount` — Inventories linked GPOs.

<!--- Results --->
%TestResult%

#### Test-MtAdGpoTotalCount

#### Why This Test Matters

Understanding the total number of Group Policy Objects (GPOs) in your Active Directory environment is crucial for several security and operational reasons:

- **Policy Sprawl**: A large number of GPOs can indicate policy sprawl, making it difficult to manage and troubleshoot policy conflicts
- **Performance Impact**: Each GPO adds processing overhead during user logon and computer startup
- **Security Complexity**: More GPOs mean more potential attack surfaces if any contain misconfigurations
- **Audit Requirements**: Compliance frameworks often require understanding of policy scope and distribution

#### Security Recommendation

Regularly audit your GPO inventory and consolidate redundant or overlapping policies. Consider:

- Merging GPOs with similar settings
- Removing unused or obsolete GPOs
- Documenting the purpose of each GPO
- Implementing a naming convention for better organization

#### How the Test Works

This test retrieves all Group Policy Objects from Active Directory and counts the total number. It uses the Get-MtADGpoState function to access cached GPO data.

#### Related Tests

- `Test-MtAdGpoUnlinkedCount` - Identifies GPOs that are not linked to any location
- `Test-MtAdGpoCreatedBefore2020Count` - Identifies potentially outdated GPOs
- `Test-MtAdGpoLinkedCount` - Counts GPOs that are actively linked

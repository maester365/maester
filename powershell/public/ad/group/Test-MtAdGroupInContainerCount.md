# Test-MtAdGroupInContainerCount

## Why This Test Matters

Active Directory supports two primary types of directory objects for storing other objects: Organizational Units (OUs) and Containers (CNs). While both can hold groups, they serve different purposes:

- **OUs (OU=)**: Designed for delegation, Group Policy application, and logical organization
- **Containers (CN=)**: System containers with limited flexibility (like CN=Users, CN=Computers)

Storing groups in containers instead of OUs creates several issues:

- **Delegation limitations**: Cannot easily delegate management of container contents
- **No Group Policy**: Cannot link Group Policy Objects to containers
- **Poor organization**: Containers lack the hierarchical flexibility of OUs
- **Security risks**: Default containers like CN=Users are well-known targets

## Security Recommendation

- Move all groups from default containers (CN=Users, CN=Builtin) to appropriate OUs
- Design an OU structure that reflects your administrative delegation model
- Implement a Group Policy strategy that works with your OU design
- Regularly audit for new groups created in containers

## How the Test Works

This test retrieves all group objects from Active Directory and analyzes their DistinguishedName property:
- Counts groups with DNs starting with "CN=" (in containers)
- Counts groups with DNs containing "OU=" (in Organizational Units)
- Calculates the percentage of groups in containers

## Related Tests

- `Test-MtAdGroupWithManagerCount` - Helps identify groups ready for delegated management
- `Test-MtAdGroupStaleCount` - Identifies groups that may need cleanup after reorganization

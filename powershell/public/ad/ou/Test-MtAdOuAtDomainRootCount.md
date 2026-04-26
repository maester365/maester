#### Test-MtAdOuAtDomainRootCount

#### Why This Test Matters

The structure of Organizational Units at the domain root level reveals important information about your Active Directory organization and management approach:

- **Directory hierarchy**: A large number of root-level OUs may indicate a flat structure that lacks organizational depth
- **Management complexity**: Many root-level OUs can make the directory harder to navigate and manage
- **Delegation planning**: Understanding root-level OUs helps with planning administrative delegation boundaries
- **Organizational alignment**: The OU structure should reflect your organization's logical structure

A well-designed OU hierarchy typically has fewer root-level OUs with meaningful nested structures beneath them, rather than many OUs all at the root level.

#### Security Recommendation

Consider implementing a hierarchical OU structure that:
- Minimizes the number of OUs at the domain root (typically 5-10 major containers)
- Groups related OUs under parent containers (e.g., by geography, department, or function)
- Makes the directory easier to navigate and manage
- Supports your Group Policy and delegation strategy

#### How the Test Works

This test retrieves all Organizational Units from Active Directory and:
- Identifies the domain's distinguished name
- Counts OUs that are direct children of the domain root
- Lists all root-level OUs with their distinguished names

#### Related Tests

- `Test-MtAdOuOverlappingNameCount` - Identifies OUs with duplicate names
- `Test-MtAdOuEmptyCount` - Finds OUs that contain no objects

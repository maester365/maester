#### Test-MtAdComputerOUCount

#### Why This Test Matters

The organizational structure of computer accounts reflects your Active Directory management maturity:

- **Management efficiency**: Well-structured OUs enable targeted Group Policy and administrative delegation
- **Security boundaries**: OUs can represent security zones with different policy requirements
- **Operational clarity**: Clear structure makes troubleshooting and auditing easier
- **Compliance alignment**: Many frameworks require logical organization of directory objects

A single flat structure (few OUs) or excessive fragmentation (many OUs with few computers) both indicate potential management challenges.

#### Security Recommendation

- Design an OU structure that supports:
  - Geographic distribution (if applicable)
  - Functional separation (workstations, servers, administrative tiers)
  - Security policy boundaries
- Avoid placing computers directly in the domain root
- Ensure the structure supports your Group Policy design
- Regularly review and consolidate underutilized OUs

#### How the Test Works

This test analyzes all enabled computer accounts and counts the distinct organizational units (containers) where computers are located. It provides insight into the breadth of your OU structure.

#### Related Tests

- `Test-MtAdComputerPerOUAverage` - Calculates the average computers per OU
- `Test-MtAdComputerInDefaultContainer` - Identifies computers in the unmanaged default container

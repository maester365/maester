#### Test-MtAdDcAllFsmoRolesCount

#### Why This Test Matters

FSMO (Flexible Single Master Operations) roles are critical directory services operations that can only be performed by one domain controller at a time:

- **Schema Master**: Controls schema updates
- **Domain Naming Master**: Controls domain additions/removals
- **PDC Emulator**: Primary DC for backward compatibility
- **RID Master**: Allocates relative IDs for SIDs
- **Infrastructure Master**: Handles cross-domain object references

Concentrating all 5 FSMO roles on a single DC creates a single point of failure. While not a direct security issue, it impacts:

- **Availability**: If the FSMO role holder fails, certain operations cannot be performed
- **Disaster recovery**: All critical roles are in one location
- **Maintenance**: Updates to the FSMO holder require careful planning

#### Security Recommendation

Consider distributing FSMO roles across multiple domain controllers for redundancy:

- Place Schema Master and Domain Naming Master in the forest root domain
- Place PDC Emulator, RID Master, and Infrastructure Master in each domain
- Ensure at least one FSMO role holder is in a different physical location
- Document FSMO role locations and transfer procedures

#### How the Test Works

This test identifies which domain controllers hold FSMO roles and counts how many DCs hold all 5 roles. It displays:
- Current FSMO role holders
- Number of unique DCs holding roles
- Whether any single DC holds all roles

#### Related Tests

- `Test-MtAdDcFsmoRoleHolderDetails` - Detailed FSMO role distribution
- `Test-MtAdDomainControllerCount` - Total DC count

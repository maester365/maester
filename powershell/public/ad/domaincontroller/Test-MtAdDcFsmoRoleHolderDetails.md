# Test-MtAdDcFsmoRoleHolderDetails

## Why This Test Matters

Understanding FSMO (Flexible Single Master Operations) role distribution is critical for:

- **Operational awareness**: Knowing which DCs perform critical directory operations
- **Disaster recovery**: Being able to quickly seize roles if a DC fails
- **Maintenance planning**: Understanding impact of DC downtime
- **Security monitoring**: Tracking changes to FSMO role holders

The 5 FSMO roles are:
1. **Schema Master** (forest-wide): Controls Active Directory schema updates
2. **Domain Naming Master** (forest-wide): Controls domain additions and removals
3. **PDC Emulator** (domain-wide): Primary DC for backward compatibility and time sync
4. **RID Master** (domain-wide): Allocates relative IDs for security identifiers
5. **Infrastructure Master** (domain-wide): Handles cross-domain object references

## Security Recommendation

- Document your FSMO role holders and keep the documentation updated
- Ensure FSMO role holders are highly available DCs
- Place at least one role holder in a different site for geographic redundancy
- Monitor for unexpected FSMO role transfers
- Test FSMO role seizure procedures periodically

## How the Test Works

This test retrieves the current FSMO role holders from the domain and forest objects, then displays:
- Which DC holds each FSMO role
- How many roles each DC holds
- Total number of unique FSMO role holders

## Related Tests

- `Test-MtAdDcAllFsmoRolesCount` - Identifies DCs holding all 5 roles
- `Test-MtAdDomainControllerCount` - Total DC count

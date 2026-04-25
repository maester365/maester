# Test-MtAdGroupPrivilegedWithMembersCount

## Why This Test Matters

Privileged groups with members require continuous monitoring as they provide administrative access:

- **Privileged access**: Members have elevated permissions in the domain
- **Attack surface**: More members increases the risk of credential compromise
- **Compliance requirements**: Most regulations require monitoring of privileged access
- **Change detection**: New memberships may indicate unauthorized elevation
- **Access review**: Supports regular attestation of privileged access

Well-known privileged groups include:
- **Domain Admins (RID 512)**: Full control of the domain
- **Enterprise Admins (RID 519)**: Full control of the forest
- **Schema Admins (RID 518)**: Can modify the Active Directory schema
- **Account Operators (RID 548)**: Can manage user and group accounts
- **Server Operators (RID 549)**: Can manage domain servers
- **Print Operators (RID 550)**: Can manage print queues
- **Backup Operators (RID 551)**: Can bypass file system security for backup

## Security Recommendation

Implement strict controls for privileged groups:
- Minimize membership in Domain Admins and Enterprise Admins
- Use Privileged Access Workstations (PAWs) for privileged accounts
- Implement just-in-time administration where possible
- Monitor and alert on privileged group changes
- Conduct regular access reviews of privileged group membership
- Document business justifications for all privileged access

## How the Test Works

This test identifies privileged groups (those with adminCount = 1 or well-known RIDs) and counts:
- Total privileged groups
- Privileged groups with members
- Privileged groups without members
- Well-known privileged groups with members

## Related Tests

- `Test-MtAdGroupPrivilegedWithMembersDetails` - Lists privileged groups with member details
- `Test-MtAdGroupEmptyNonPrivilegedCount` - Reviews non-privileged empty groups

#### Test-MtAdGroupPrivilegedWithMembersDetails

#### Why This Test Matters

Understanding which privileged accounts have access is fundamental to Active Directory security:

- **Identity management**: Know who has administrative access
- **Over-privilege detection**: Identify accounts with excessive permissions
- **Attack path analysis**: Understand potential lateral movement routes
- **Compliance evidence**: Document privileged access for audits
- **Access certification**: Support periodic access reviews

Well-known privileged groups:
- **Domain Admins (RID 512)**: Full administrative control of the domain
- **Enterprise Admins (RID 519)**: Full administrative control of the forest
- **Schema Admins (RID 518)**: Can modify Active Directory schema
- **Account Operators (RID 548)**: Can manage user and group accounts
- **Server Operators (RID 549)**: Can manage domain servers
- **Print Operators (RID 550)**: Can manage print services
- **Backup Operators (RID 551)**: Can bypass file security for backup

#### Security Recommendation

Review privileged group membership regularly:
- Document all members and their justifications
- Remove stale or unnecessary memberships
- Verify service accounts aren't in privileged groups unnecessarily
- Consider implementing privileged access management (PAM) solutions
- Use separate administrative accounts for privileged activities
- Implement time-bound access for privileged roles
- Monitor for new privileged group additions

#### How the Test Works

This test lists all privileged groups (those with adminCount = 1 or well-known RIDs) and provides:
- Group name and RID
- Member count for each group
- Categorization by well-known vs. AdminSDHolder protected groups
- Total members across all privileged groups

#### Related Tests

- `Test-MtAdGroupPrivilegedWithMembersCount` - Counts privileged groups with members
- `Test-MtAdGroupMemberForeignSidDetails` - Reviews foreign security principals in groups

Most user accounts use `PrimaryGroupId = 513`, which corresponds to `Domain Users`. When a user has a different primary group, the configuration is often intentional but uncommon.

- **Privilege review**: Non-standard primary groups can indicate elevated or specialized access models
- **Migration residue**: Legacy migrations and scripted provisioning may leave unusual values behind
- **Access clarity**: Atypical primary groups make account analysis more complex

#### Control Type

**Detective**

#### Security Recommendation

- Review users whose `PrimaryGroupId` is not `513`
- Confirm the configuration is required and documented
- Standardize primary groups where there is no operational reason for deviation

#### How the Test Works

This test counts user objects where `primaryGroupId` is populated and not equal to `513`.

#### Related Tests

- `Test-MtAdUserAdminCountCount` - Highlights protected or privileged accounts
- `Test-MtAdUserSidHistoryCount` - Identifies migration-related account artifacts

#### Related links

- [Microsoft Defender for Identity: Accounts with non-default Primary Group ID](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#accounts-with-non-default-primary-group-id)
- [ANSSI Active Directory checkpoints: Accounts with modified PrimaryGroupID](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_primary_group_id_nochange)

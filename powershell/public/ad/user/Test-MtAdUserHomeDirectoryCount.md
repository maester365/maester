#### Test-MtAdUserHomeDirectoryCount

#### Why This Test Matters

The `HomeDirectory` attribute points users to network-based storage locations. While useful in legacy environments, it can reveal older provisioning patterns and dependencies on file servers.

- **Legacy infrastructure visibility**: Identifies users tied to mapped-drive style home folders
- **Access control review**: Highlights centralized storage paths that may contain sensitive data
- **Modernization planning**: Helps quantify remaining on-premises file service dependencies

#### Security Recommendation

- Review home directory locations for proper ACLs and ownership controls
- Confirm the attribute is still required for active users
- Retire obsolete mappings and legacy storage dependencies where feasible

#### How the Test Works

This test counts user objects where the `HomeDirectory` attribute contains a non-empty value.

#### Related Tests

- `Test-MtAdUserProfilePathCount` - Finds roaming profile dependencies
- `Test-MtAdUserScriptPathCount` - Identifies legacy logon automation

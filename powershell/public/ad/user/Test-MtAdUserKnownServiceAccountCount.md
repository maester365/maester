#### Test-MtAdUserKnownServiceAccountCount

#### Why This Test Matters

Many environments use recognizable naming conventions for service accounts such as `svc_`, `service_`, or `_svc`. These patterns make service accounts easier to inventory and harden.

- **Service account inventory**: Helps locate likely service identities quickly
- **Hardening prioritization**: Supports focused review of passwords, SPNs, and delegation
- **Monitoring alignment**: Makes it easier to target logon, privilege, and usage monitoring

#### Security Recommendation

- Review accounts matching known service account naming patterns for proper ownership and documentation
- Apply stronger controls to service accounts, including long random passwords and interactive logon restrictions
- Prefer managed service account options where the workload supports them

#### How the Test Works

This test counts user objects whose `SamAccountName` or `Name` matches common service account naming patterns such as `svc_`, `service_`, `_svc`, `sa_`, and similar variants.

#### Related Tests

- `Test-MtAdUserSpnSetCount` - Identifies service accounts through SPN usage
- `Test-MtAdUserAdminCountCount` - Highlights service accounts that may also be protected or privileged

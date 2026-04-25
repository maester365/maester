# Test-MtAdUserInContainerCount

## Why This Test Matters

Users are easier to manage when placed in organizational units (OUs) that align to administration, policy, and lifecycle requirements. Accounts stored in container paths such as `CN=Users` often indicate default placement or limited organizational structure.

- **Delegation limitations**: Containers are less flexible for delegated administration
- **Policy design impact**: OUs are the preferred structure for policy and lifecycle management
- **Default placement visibility**: Helps identify accounts still living in `CN=Users` or similar container paths

## Security Recommendation

- Move standard user accounts from container paths into appropriate OUs
- Define an OU model that supports administration, policy, and lifecycle requirements
- Regularly review new accounts for default or non-standard placement

## How the Test Works

This test counts user objects whose distinguished names indicate they are beneath a container path, including accounts under `CN=Users`.

## Related Tests

- `Test-MtAdUserManagerSetCount` - Helps assess whether organizational metadata is mature enough for governance
- `Test-MtAdUserKnownServiceAccountCount` - Finds service accounts that may also require dedicated OUs

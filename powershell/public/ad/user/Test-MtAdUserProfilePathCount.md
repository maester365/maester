# Test-MtAdUserProfilePathCount

## Why This Test Matters

The `ProfilePath` attribute is commonly associated with roaming profiles and centralized workstation state. It often points to legacy file server infrastructure that should be reviewed for resilience and access control.

- **Legacy profile management**: Identifies users depending on roaming profiles
- **Data exposure review**: Highlights centralized storage paths that may require tighter controls
- **Operational dependency mapping**: Helps quantify reliance on older desktop management models

## Security Recommendation

- Review profile share permissions and access paths
- Confirm roaming profiles are still necessary for affected users
- Consider modern endpoint and profile management approaches where appropriate

## How the Test Works

This test counts user objects where the `ProfilePath` attribute contains a non-empty value.

## Related Tests

- `Test-MtAdUserHomeDirectoryCount` - Highlights related file share dependencies
- `Test-MtAdUserScriptPathCount` - Finds additional legacy sign-in configuration

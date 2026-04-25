# Test-MtAdUserScriptPathCount

## Why This Test Matters

The `ScriptPath` attribute can launch scripts automatically during user sign-in. These scripts may map drives, alter environment settings, or execute legacy administrative logic.

- **Execution surface**: Logon scripts can introduce code execution paths during authentication
- **Legacy dependency detection**: Helps identify environments still relying on older sign-in automation
- **Review priority**: Highlights scripts and shares that may need access hardening or modernization

## Security Recommendation

- Review every configured logon script for business need and secure coding practices
- Protect the storage locations that host scripts from unauthorized modification
- Retire unnecessary scripts and move critical logic to managed modern tooling where possible

## How the Test Works

This test counts user objects where the `ScriptPath` attribute contains a non-empty value.

## Related Tests

- `Test-MtAdUserHomeDirectoryCount` - Identifies related legacy provisioning settings
- `Test-MtAdUserProfilePathCount` - Finds users with additional sign-in infrastructure dependencies

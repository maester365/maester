# Test-MtAdSchemaVersionEntryCount

## Why This Test Matters

The Active Directory schema version indicates the functional level and capabilities of your directory. Different schema versions correspond to different Windows Server releases:

| Schema Version | Windows Server Version |
|----------------|----------------------|
| 13 | Windows 2000 |
| 30 | Windows Server 2003 |
| 44 | Windows Server 2008 |
| 47 | Windows Server 2008 R2 |
| 56 | Windows Server 2012 |
| 69 | Windows Server 2012 R2 |
| 87 | Windows Server 2016 |
| 88 | Windows Server 2019/2022 |

Knowing your schema version is important for:
- **Compatibility**: Ensuring applications support your schema version
- **Feature availability**: Understanding what AD features are available
- **Upgrade planning**: Determining if schema updates are needed
- **Security**: Newer schema versions support enhanced security features

## Security Recommendation

Keep your schema version current with your domain functional level:
- **Regular updates**: Update schema when upgrading domain controllers
- **Feature enablement**: Newer schemas enable security features like Authentication Policies
- **Application support**: Modern applications may require newer schema versions

## How the Test Works

This test retrieves the objectVersion attribute from the schema container to determine the current schema version and maps it to the corresponding Windows Server version.

## Related Tests

- `Test-MtAdSchemaVersionDetails` - Provides comprehensive schema details
- `Test-MtAdSchemaModificationYearCount` - Shows schema modification timeline
- `Test-MtAdDomainFunctionalLevel` - Shows domain functional level

The Active Directory schema version tracks schema updates, not the domain or forest functional level. Different schema versions correspond to different Windows Server releases:

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
| 91 | Windows Server 2025 |

Knowing your schema version is important for:
- **Compatibility**: Ensuring applications support your schema version
- **Feature availability**: Understanding what AD features are available
- **Upgrade planning**: Determining if schema updates are needed
- **Security**: Newer schema versions support enhanced security features

#### Control Type

**Operational**

#### Security Recommendation

Plan schema updates separately from domain functional-level changes:
- **Regular updates**: Update schema when upgrading domain controllers
- **Feature enablement**: Newer schemas enable security features like Authentication Policies
- **Application support**: Modern applications may require newer schema versions

#### How the Test Works

This test retrieves `objectVersion` from the schema container, maps it to a Windows Server release, and lists **all** schema objects whose `objectClass` includes `classSchema` (name and distinguished name). It does not arbitrarily truncate the class list or claim a domain functional level.

#### Related Tests

- `Test-MtAdSchemaModificationYearCount` (AD-SCH-01) - Shows schema object creation years and details
- `Test-MtAdDomainFunctionalLevel` - Shows domain functional level

<!--- Results --->
%TestResult%

#### Test-MtAdDcOperatingSystemCount

#### Why This Test Matters

Knowing the operating systems running on your domain controllers is important for:

- **Lifecycle management**: Identifying DCs running end-of-life operating systems
- **Security patching**: Ensuring all DCs receive security updates
- **Feature availability**: Determining which AD features are available
- **Standardization**: Reducing OS variety for easier management
- **Upgrade planning**: Identifying DCs that need to be upgraded

Running outdated operating systems on domain controllers poses security risks as they may not receive security patches.

#### Security Recommendation

- Standardize on a supported Windows Server version for all DCs
- Plan to upgrade DCs running end-of-life operating systems
- Ensure all DCs are receiving security updates
- Consider running the latest Windows Server version for new DCs

Current Windows Server support status:
- Windows Server 2022: Supported
- Windows Server 2019: Supported
- Windows Server 2016: Supported
- Windows Server 2012 R2: Extended support ended October 2023
- Windows Server 2012: Extended support ended October 2023
- Earlier versions: Not supported

#### How the Test Works

This test retrieves the OperatingSystem attribute from all domain controllers and counts the unique OS versions in use.

#### Related Tests

- `Test-MtAdDcOperatingSystemDetails` - Detailed OS distribution breakdown
- `Test-MtAdDomainControllerCount` - Total DC count

# Test-MtAdDcOperatingSystemDetails

## Why This Test Matters

Understanding the operating system distribution across your domain controllers helps with:

- **Security compliance**: Identifying DCs on unsupported OS versions
- **Patch management**: Planning update cycles across different OS versions
- **Upgrade planning**: Prioritizing which DCs to upgrade first
- **Capacity planning**: Understanding feature availability across DCs
- **Risk assessment**: Evaluating exposure from outdated systems

Domain controllers running end-of-life operating systems are a critical security risk as they no longer receive security updates, making them vulnerable to known exploits.

## Security Recommendation

**Upgrade domain controllers running end-of-life operating systems immediately.**

Priority order for upgrades:
1. Windows Server 2008 R2 and earlier (unsupported)
2. Windows Server 2012/2012 R2 (extended support ended)
3. Windows Server 2016 (still supported, but older)

Upgrade process:
1. Promote new DCs on supported OS versions
2. Transfer FSMO roles if needed
3. Demote old DCs
4. Remove from domain

## How the Test Works

This test retrieves the OperatingSystem attribute from all domain controllers and groups them by OS version, showing:
- Count of DCs per OS version
- Percentage distribution
- Names of DCs running each OS

## Related Tests

- `Test-MtAdDcOperatingSystemCount` - Count of unique OS versions
- `Test-MtAdDomainControllerCount` - Total DC count

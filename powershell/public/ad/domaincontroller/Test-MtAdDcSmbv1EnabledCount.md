# Test-MtAdDcSmbv1EnabledCount

## Why This Test Matters

SMBv1 (Server Message Block version 1) is an outdated protocol with significant security vulnerabilities:

- **EternalBlue exploit**: Used in WannaCry and NotPetya ransomware attacks
- **No encryption**: SMBv1 traffic is not encrypted
- **No integrity checks**: Vulnerable to man-in-the-middle attacks
- **Deprecated by Microsoft**: Microsoft strongly recommends disabling SMBv1

Domain controllers with SMBv1 enabled pose a critical security risk as they are high-value targets for attackers.

## Security Recommendation

**Disable SMBv1 on all domain controllers immediately.**

To disable SMBv1 on a domain controller:
```powershell
# Check current status
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol

# Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

# Disable SMBv1 feature (requires restart)
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
```

## How the Test Works

This test queries the SMB server configuration on each domain controller to check if SMBv1 protocol is enabled. It reports:
- Number of DCs with SMBv1 enabled
- Names of affected DCs
- Overall security status

## Related Tests

- `Test-MtAdDcSmbSigningEnabledCount` - SMB signing configuration
- `Test-MtAdDcSmbv311EnabledCount` - SMBv3.1.1 protocol status

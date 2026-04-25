# Test-MtAdDcSmbv311EnabledCount

## Why This Test Matters

SMBv3.1.1 is the latest version of the Server Message Block protocol and includes important security enhancements:

- **Pre-authentication integrity**: Prevents man-in-the-middle attacks
- **AES-128-GCM encryption**: Stronger encryption for SMB traffic
- **Secure dialect negotiation**: Prevents downgrade attacks
- **Required for Windows 11**: Modern Windows versions prefer SMBv3.1.1

Having SMBv3.1.1 enabled ensures your domain controllers can support the most secure SMB communications.

## Security Recommendation

Enable SMBv3.1.1 on all domain controllers running Windows Server 2016 or later to ensure maximum SMB security.

To verify SMBv3.1.1 status:
```powershell
Get-SmbServerConfiguration | Select-Object EnableSMB3_1_1Protocol
```

## How the Test Works

This test queries the SMB server configuration on each domain controller to check if SMBv3.1.1 protocol is enabled. It reports the count and names of DCs with this protocol enabled.

## Related Tests

- `Test-MtAdDcSmbv1EnabledCount` - SMBv1 protocol status (should be disabled)
- `Test-MtAdDcSmbSigningEnabledCount` - SMB signing configuration

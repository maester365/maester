#### Test-MtAdDcSmbSigningEnabledCount

#### Why This Test Matters

SMB signing (also known as security signatures) is a security feature that helps prevent:

- **Man-in-the-middle attacks**: Attackers cannot modify SMB packets in transit
- **Session hijacking**: Ensures the integrity of SMB sessions
- **Replay attacks**: Prevents attackers from replaying captured SMB traffic

Without SMB signing, an attacker on the network could intercept and modify SMB traffic between clients and domain controllers.

#### Security Recommendation

**Enable SMB signing on all domain controllers.**

To enable SMB signing:
```powershell
#### Check current status
Get-SmbServerConfiguration | Select-Object EnableSecuritySignature, RequireSecuritySignature

#### Enable SMB signing
Set-SmbServerConfiguration -EnableSecuritySignature $true -RequireSecuritySignature $true -Force
```

You can also enforce SMB signing through Group Policy:
- Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options
- "Microsoft network server: Digitally sign communications (always)" = Enabled

#### How the Test Works

This test queries the SMB server configuration on each domain controller to check if SMB signing is enabled and required. It reports:
- Number of DCs with signing enabled
- Number of DCs with signing required
- Names of DCs without signing enabled

#### Related Tests

- `Test-MtAdDcSmbv1EnabledCount` - SMBv1 protocol status
- `Test-MtAdDcSmbv311EnabledCount` - SMBv3.1.1 protocol status

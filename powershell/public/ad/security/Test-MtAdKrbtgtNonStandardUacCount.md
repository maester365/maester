#### Test-MtAdKrbtgtNonStandardUacCount

#### Why This Test Matters

- The KRBTGT account must have specific User Account Control (UAC) settings to maintain security. The standard UAC value for KRBTGT is 514, which represents:

- **NORMAL_ACCOUNT (0x0200 = 512)**: Standard user account
- **ACCOUNTDISABLE (0x0002 = 2)**: Account is disabled
- **Combined: 514 (0x0202)**

**Security Risks of Non-Standard UAC:**
- **Enabled Account**: KRBTGT should never be enabled
- **Delegation Flags**: Could allow dangerous delegation configurations
- **Password Flags**: DONT_EXPIRE_PASSWORD could prevent required rotations
- **Tampering Indicator**: Non-standard UAC may suggest malicious modification

#### Security Recommendation

1. **Maintain standard UAC (514)**:
   - Account must remain disabled
   - No additional flags should be set
   - Regular audits of UAC settings

2. **Investigate non-standard UAC immediately**:
   - Determine who made changes
   - Assess if compromise has occurred
   - Reset UAC to standard value (514)

3. **Monitor for changes**:
   - Implement alerts for KRBTGT account modifications
   - Include UAC changes in security monitoring

#### How the Test Works

This test retrieves the KRBTGT account and:
- Compares current UAC against standard value (514)
- Decodes and displays all UAC flags
- Reports any non-standard configurations

#### Related Tests

- `Test-MtAdKrbtgtPasswordLastSet` - Checks KRBTGT password age
- `Test-MtAdKrbtgtLastLogon` - Verifies no interactive logons

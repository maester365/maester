#### Test-MtAdKrbtgtLastLogon

#### Why This Test Matters

The KRBTGT account is a service account that should never have interactive logons. It exists solely for the KDC service to use internally for Kerberos ticket operations. Any logon activity for this account may indicate:

**Security Concerns:**
- **Suspicious Activity**: Interactive logons suggest potential compromise or misuse
- **Account Misuse**: Administrators incorrectly attempting to use the account
- **Attack Indicators**: Attackers may attempt to activate or use the account

The KRBTGT account should:
- Always remain disabled (UAC = 514)
- Never have interactive logons
- Only be used internally by the KDC service

#### Security Recommendation

1. **Never enable the KRBTGT account**:
   - Standard UAC should be 514 (disabled, normal account)
   - Enabling this account creates a significant security risk

2. **Monitor for logon attempts**:
   - Any logon activity should be investigated immediately
   - Check security logs for attempted logons to this account

3. **Audit account changes**:
   - Monitor for UAC changes
   - Alert on any modifications to the KRBTGT account

#### How the Test Works

This test retrieves the KRBTGT account and checks:
- Last logon timestamp (should be null/never)
- Account enabled status (should be disabled)
- Password last set date

#### Related Tests

- `Test-MtAdKrbtgtPasswordLastSet` - Checks KRBTGT password age
- `Test-MtAdKrbtgtNonStandardUacCount` - Validates KRBTGT UAC settings

# Test-MtAdLapsInstalledStatus

## Why This Test Matters

The Local Administrator Password Solution (LAPS) is a critical security tool that:

- **Manages local admin passwords**: Automatically rotates passwords on domain-joined computers
- **Prevents lateral movement**: Eliminates shared local administrator passwords
- **Secure storage**: Stores passwords securely in Active Directory attributes
- **Access control**: Controls who can retrieve local administrator passwords
- **Audit trail**: Logs password access for compliance

Without LAPS, organizations commonly face these risks:
- **Pass-the-hash attacks**: Attackers use shared local credentials to move laterally
- **Persistent access**: Compromised local accounts provide ongoing access
- **Credential stuffing**: Shared passwords reused across multiple systems
- **Compliance failures**: Many frameworks require unique local admin passwords

## Security Recommendation

Deploy LAPS across your entire domain:

1. **Install LAPS**: Download from Microsoft and extend the AD schema
2. **Group Policy**: Configure password rotation policies (recommended: every 30 days)
3. **Access controls**: Limit who can read the ms-Mcs-AdmPwd attribute
4. **Monitoring**: Alert on password retrieval events
5. **Legacy LAPS**: Consider upgrading to Windows LAPS (built into Windows 11/Server 2022)

## How the Test Works

This test checks for the presence of LAPS schema attributes (ms-Mcs-AdmPwd) to determine if LAPS has been installed and configured in the Active Directory environment.

## Related Tests

- `Test-MtAdComputerUnconstrainedDelegationCount` - Check for delegation risks
- `Test-MtAdUserPasswordNeverExpiresCount` - Identify password policy gaps
- `Test-MtAdPasswordComplexityRequired` - Verify password policies

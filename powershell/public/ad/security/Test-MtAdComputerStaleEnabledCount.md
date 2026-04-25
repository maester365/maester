# Test-MtAdComputerStaleEnabledCount

## Why This Test Matters

Stale enabled computer accounts represent a significant security risk in Active Directory. These are computer accounts that remain enabled but have not authenticated to the domain for an extended period (typically 180 days or more).

**Security Risks:**
- **Attack Vector**: Stale accounts can be compromised and reactivated by attackers
- **Lateral Movement**: Compromised stale accounts provide footholds for lateral movement
- **Credential Theft**: May have weak or unchanged passwords
- **Shadow IT**: May indicate forgotten or unauthorized systems
- **Compliance Issues**: Violates security policies requiring regular account review

**Common Causes:**
- Decommissioned systems that were never disabled
- Virtual machines that were deleted but not removed from AD
- Test systems that are no longer in use
- Hardware refreshes where old accounts remain

## Security Recommendation

1. **Regular Review Process**:
   - Quarterly review of stale enabled computers
   - Document business justification for exceptions
   - Automate detection and reporting

2. **Remediation Actions**:
   - Disable computers after 90-180 days of inactivity
   - Delete disabled computers after additional review period
   - Verify with system owners before deletion

3. **Preventive Measures**:
   - Implement automated provisioning/deprovisioning
   - Use computer account lifecycle management
   - Regular audits of computer account creation

## How the Test Works

This test identifies enabled computers that:
- Have never logged on, OR
- Have not logged on for 180+ days

Provides counts and lists affected computers.

## Related Tests

- `Test-MtAdComputerDormantCount` - Dormant computer identification
- `Test-MtAdComputerDisabledCount` - Disabled computer analysis
- `Test-MtAdUserDormantEnabledCount` - Stale user account check

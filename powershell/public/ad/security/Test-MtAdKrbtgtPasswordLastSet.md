#### Test-MtAdKrbtgtPasswordLastSet

#### Why This Test Matters

The KRBTGT account is the most critical service account in Active Directory. It is used by the Key Distribution Center (KDC) service to encrypt and sign all Kerberos tickets within the domain. If this account is compromised, an attacker can forge Kerberos tickets (Golden Tickets) that grant unlimited access to any resource in the domain.

**Security Risks:**
- **Golden Ticket Attacks**: Compromised KRBTGT password allows attackers to forge TGTs for any user
- **Persistent Access**: Attackers can maintain access even after password changes if they create forged tickets with long lifetimes
- **Domain-Wide Impact**: A single compromised KRBTGT affects the entire domain

#### Security Recommendation

1. **Rotate KRBTGT password regularly**:
   - At least every 180 days (twice per year)
   - Immediately if compromise is suspected

2. **If compromise is suspected**:
   - Rotate the password **twice** with at least 10 hours between rotations
   - First rotation invalidates existing forged tickets
   - Second rotation ensures any tickets created between rotations are also invalidated

3. **Monitor for anomalies**:
   - Unexpected password changes
   - Unusual authentication patterns
   - KRBTGT account being enabled (it should always be disabled)

#### How the Test Works

This test retrieves the KRBTGT account from Active Directory and checks:
- Password last set date
- Days since last password change
- Account status (should be disabled)

#### Related Tests

- `Test-MtAdKrbtgtLastLogon` - Verifies KRBTGT has no interactive logons
- `Test-MtAdKrbtgtNonStandardUacCount` - Validates KRBTGT has standard UAC settings

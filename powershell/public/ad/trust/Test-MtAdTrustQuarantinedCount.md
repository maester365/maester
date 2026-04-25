# Test-MtAdTrustQuarantinedCount

## Why This Test Matters

SID filtering (quarantined trusts) is a critical security control for inter-forest trusts:

- **Prevents Privilege Escalation**: Blocks malicious SID history from being honored across trust boundaries
- **Limits Blast Radius**: Contains the impact of a compromised external domain
- **Security Best Practice**: Microsoft recommends SID filtering for all external trusts
- **Compliance Requirement**: Many security frameworks require SID filtering on external trusts

Without SID filtering, an attacker who compromises a domain in a trusting forest could inject SIDs from the trusted forest's privileged groups (like Domain Admins or Enterprise Admins) into their own account, effectively gaining privileged access across the trust boundary.

## Security Recommendation

- **Enable SID Filtering**: Enable SID filtering (quarantine) on ALL inter-forest trusts
- **Audit Regularly**: Regularly verify that external trusts remain quarantined
- **Document Exceptions**: If SID filtering cannot be enabled, document the risk and compensating controls
- **Use Forest Trusts**: When possible, use forest trusts instead of external trusts as they provide better security controls
- **Monitor Changes**: Alert on any changes to trust quarantine status

## How the Test Works

This test checks the `Quarantined` property of each trust object. When `Quarantined` is `$true`, SID filtering is enabled. The test returns:

- Total count of trusts
- Count of quarantined trusts (SID filtering enabled)
- Count of non-quarantined trusts (SID filtering disabled)

## Related Tests

- `Test-MtAdTrustNonQuarantinedDetails` - Lists specific trusts without SID filtering
- `Test-MtAdTrustInterForestCount` - Identifies external trusts that should be quarantined
- `Test-MtAdTrustDetails` - Shows quarantine status for all trusts

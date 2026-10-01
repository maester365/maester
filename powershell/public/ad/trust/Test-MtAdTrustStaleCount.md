#### Test-MtAdTrustStaleCount

#### Why This Test Matters

Stale trusts (those not validated for extended periods) indicate potential issues:

- **Decommissioned Domains**: The target domain may no longer exist
- **Connectivity Issues**: Network problems preventing trust validation
- **Orphaned Trusts**: Trusts created for temporary purposes that were never removed
- **Security Hygiene**: Unused trusts increase attack surface unnecessarily
- **Operational Risk**: Stale trusts may fail unexpectedly when needed

Trust validation occurs when the trusting domain attempts to verify the trust relationship with the trusted domain. If this hasn't happened in 60+ days, it suggests the trust is not actively used.

#### Security Recommendation

**Immediate Actions:**
- Review all stale trusts to determine if they are still needed
- Test connectivity to the target domain
- Verify the target domain still exists

**Remediation Steps:**
1. **Verify Need**: Confirm if the trust serves a business purpose
2. **Test Connectivity**: Attempt to validate the trust manually
3. **Remove if Unused**: Delete trusts that are no longer needed
4. **Document Exceptions**: For trusts that must remain, document why

**Command to Validate a Trust:**
```powershell
Test-ADTrust -Target <TrustName>
```

**Command to Remove a Trust:**
```powershell
Remove-ADTrust -Target <TrustName>
```

#### How the Test Works

This test checks the `LastValidated` property of each trust. Trusts are considered stale if:
- `LastValidated` is not null
- `LastValidated` is more than 60 days in the past

The test returns:
- Total trust count
- Count of stale trusts
- Count of trusts with unknown validation status
- Count of valid trusts

#### Related Tests

- `Test-MtAdTrustStaleDetails` - Lists specific stale trusts with details
- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustDetails` - Complete trust configuration including last validated date

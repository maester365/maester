#### Test-MtAdTrustStaleDetails

#### Why This Test Matters

Identifying specific stale trusts enables targeted remediation:

- **Prioritization**: Focus cleanup efforts on the oldest, most likely unused trusts
- **Investigation**: Specific target domains can be investigated for existence and need
- **Risk Assessment**: Older trusts may represent higher security risks
- **Documentation**: Detailed stale trust information supports decision-making
- **Compliance**: Demonstrates active trust management for audits

Stale trusts often accumulate over time as:
- Temporary project trusts are forgotten
- Acquired company domains are decommissioned
- Network restructuring leaves orphaned connections
- Test environments are removed without cleanup

#### Security Recommendation

**Investigation Process:**

1. **Identify Target Domain**: Determine if the target domain still exists
2. **Check Business Need**: Verify if any systems still require the trust
3. **Test Validation**: Attempt manual trust validation
4. **Plan Removal**: Schedule removal if trust is confirmed unused
5. **Document**: Record removal rationale for audit purposes

**Sample Investigation Commands:**
```powershell
#### Test if the trust can be validated
Test-ADTrust -Target <TrustName>

#### Check when the trust was created
Get-ADTrust -Filter {Target -eq "<TrustName>"} -Properties Created

#### View detailed trust information
Get-ADTrust -Filter {Target -eq "<TrustName>"} -Properties *
```

**Removal Process:**
- Notify stakeholders before removing production trusts
- Remove during maintenance windows
- Document removal in change management system
- Monitor for any authentication failures after removal

#### How the Test Works

This test identifies trusts where `LastValidated` is more than 60 days old and displays:

- Target domain name
- Trust direction
- Last validation date
- Days since last validation
- Trust type

Results are sorted by last validation date (oldest first).

#### Related Tests

- `Test-MtAdTrustStaleCount` - Count of stale trusts
- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustDetails` - Complete trust configuration information

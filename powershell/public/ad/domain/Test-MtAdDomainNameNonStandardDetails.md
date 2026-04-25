# Test-MtAdDomainNameNonStandardDetails

## Why This Test Matters

This test provides detailed information about non-compliant domain names, helping you:

- **Identify Problem Domains**: Pinpoint exactly which domains have naming issues
- **Plan Remediation**: Understand the specific compliance violations
- **Document Exceptions**: Create records of non-compliant names for audit purposes
- **Prevent Future Issues**: Ensure new domains follow naming standards

## Security Recommendation

When non-compliant domain names are identified:

1. **Assess Impact**: Determine if the non-compliance causes actual operational issues
2. **Document**: Record the domain names and reasons for non-compliance
3. **Plan Migration**: If rename is necessary, plan carefully as it's a complex operation
4. **Prevent**: Establish naming standards for future domain additions

## How the Test Works

This test checks each domain name label against RFC 1123 standards and provides detailed information about which specific labels are non-compliant and why.

## Related Tests

- `Test-MtAdDomainNameStandardCompliance` - Counts non-compliant domain names
- `Test-MtAdNetbiosNameNonStandardDetails` - Lists non-compliant NetBIOS names

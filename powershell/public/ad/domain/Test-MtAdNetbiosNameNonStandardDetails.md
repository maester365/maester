# Test-MtAdNetbiosNameNonStandardDetails

## Why This Test Matters

This test provides detailed information about NetBIOS naming violations, helping you:

- **Identify Specific Issues**: See exactly which characters or length issues exist
- **Plan Corrections**: Understand what needs to change to achieve compliance
- **Document Exceptions**: Record non-compliant names and their specific issues
- **Prevent Problems**: Address issues before they cause application failures

## Security Recommendation

When non-compliant NetBIOS names are identified:

1. **Review Impact**: Determine if the naming issues affect critical systems
2. **Assess Change Feasibility**: NetBIOS name changes require domain reconfiguration
3. **Document Workarounds**: If names can't be changed, document mitigation strategies
4. **Enforce Standards**: Implement naming policies for future domains

## How the Test Works

This test checks each NetBIOS name for length compliance (1-15 characters) and invalid characters (\ / : * ? " < > |), providing detailed issue descriptions.

## Related Tests

- `Test-MtAdNetbiosNameStandardCompliance` - Counts non-compliant NetBIOS names
- `Test-MtAdDomainNameNonStandardDetails` - Lists non-compliant domain names

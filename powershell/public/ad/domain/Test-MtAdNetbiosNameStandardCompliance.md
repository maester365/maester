# Test-MtAdNetbiosNameStandardCompliance

## Why This Test Matters

NetBIOS names are still used in many Windows networking scenarios, even though DNS is the primary name resolution method. Non-compliant NetBIOS names can cause:

- **Legacy Application Issues**: Older applications may not handle non-standard characters
- **WINS Problems**: Windows Internet Name Service may have trouble with invalid names
- **Network Browsing**: Issues with network neighborhood and browsing services
- **Script Failures**: PowerShell and batch scripts may fail with special characters

Valid NetBIOS names should:
- Be 1-15 characters in length
- Contain only alphanumeric characters and: !@#$%^&'()_-.+{}~
- Not contain: \ / : * ? " < > |

## Security Recommendation

- **Use Simple Names**: Stick to alphanumeric characters for maximum compatibility
- **Keep Short**: Stay well under the 15-character limit
- **Avoid Special Characters**: Even allowed special characters can cause issues
- **Document Requirements**: If special characters are needed, document the business case

## How the Test Works

This test validates NetBIOS names against standard naming conventions, checking for valid characters and length requirements.

## Related Tests

- `Test-MtAdNetbiosNameNonStandardDetails` - Lists non-compliant NetBIOS names
- `Test-MtAdDomainNameStandardCompliance` - Checks domain name compliance

#### Test-MtAdDnsNonStandardZoneCount

#### Why This Test Matters

Non-standard DNS zone names (not compliant with RFCs 952, 1035, and 1123) may cause:

- **Compatibility issues**: Some DNS clients and applications may fail
- **Resolution problems**: Non-standard names may not resolve correctly
- **Management difficulties**: Unusual characters can complicate administration
- **Security risks**: Special characters might be used in injection attacks

Standard DNS names should contain only letters, numbers, and hyphens.

#### Security Recommendation

- Use only RFC-compliant names for DNS zones
- Rename or remove zones with non-standard names
- Implement naming conventions that follow RFC standards
- Audit zone names regularly for compliance

#### How the Test Works

This test identifies zones with names that do not comply with RFC standards for internet domain names, excluding special zones like TrustAnchors and _msdcs.

#### Related Tests

- None currently

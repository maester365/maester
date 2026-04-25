# Test-MtAdSupportedSaslMechanismCount

## Why This Test Matters

SASL (Simple Authentication and Security Layer) mechanisms define the authentication protocols that Active Directory supports. Understanding these mechanisms is important for:

- **Authentication Security**: Different mechanisms provide different security levels
- **Protocol Compatibility**: Ensuring clients can authenticate using appropriate methods
- **Security Baseline**: Tracking changes to supported mechanisms that could indicate misconfiguration

The default count is typically 4 mechanisms (GSSAPI, GSS-SPNEGO, EXTERNAL, DIGEST-MD5), though this may vary by configuration.

## Security Recommendation

- Prefer Kerberos (GSSAPI) for authentication when possible
- Minimize use of less secure mechanisms like DIGEST-MD5
- Monitor for unexpected changes to supported SASL mechanisms
- Disable mechanisms that are not required in your environment
- Ensure clients are configured to use the most secure available mechanism

## How the Test Works

This test retrieves the Root DSE and counts:
- Number of supported SASL mechanisms
- List of mechanism names

## Related Tests

- `Test-MtAdSupportedSaslMechanismDetails` - Provides detailed information about each mechanism

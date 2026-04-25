# Test-MtAdSupportedSaslMechanismDetails

## Why This Test Matters

Understanding the SASL (Simple Authentication and Security Layer) mechanisms supported by Active Directory is crucial for authentication security:

- **Security Levels**: Different mechanisms offer varying levels of security
- **Protocol Selection**: Clients negotiate authentication based on available mechanisms
- **Attack Surface**: Unnecessary mechanisms increase the authentication attack surface
- **Compliance**: Some regulations may require specific authentication protocols

Common mechanisms and their security levels:
- **GSSAPI (Kerberos)**: Highest security, mutual authentication
- **GSS-SPNEGO**: Negotiate between Kerberos and NTLM
- **EXTERNAL**: TLS client certificate authentication
- **DIGEST-MD5**: Less secure, often disabled in hardened environments

## Security Recommendation

- Use Kerberos (GSSAPI) as the primary authentication mechanism
- Disable DIGEST-MD5 if not explicitly required
- Enable EXTERNAL for certificate-based authentication scenarios
- Monitor authentication logs for mechanism usage patterns
- Document which mechanisms are required for your environment

## How the Test Works

This test retrieves detailed information about each supported SASL mechanism:
- Mechanism name
- Description of the mechanism
- Security level assessment

## Related Tests

- `Test-MtAdSupportedSaslMechanismCount` - Counts total supported mechanisms

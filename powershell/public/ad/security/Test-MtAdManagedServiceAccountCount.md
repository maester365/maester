#### Test-MtAdManagedServiceAccountCount

#### Why This Test Matters

- Managed Service Accounts (MSAs) and Group Managed Service Accounts (gMSAs) provide significant security improvements over traditional service accounts by automating password management and simplifying service principal name (SPN) management.

**Security Benefits:**
- **Automatic Password Rotation**: Passwords change automatically (every 30 days for gMSAs)
- **Eliminates Manual Management**: No need for administrators to manage service account passwords
- **No Interactive Logon**: Cannot be used for interactive logon, reducing attack surface
- **Reduced Credential Theft Risk**: Passwords are complex and regularly changed
- **Simplified Administration**: No manual password changes or coordination required

**Types of Managed Service Accounts:**
- **Standalone MSA**: For use on a single computer (legacy, largely replaced by gMSA)
- **Group MSA (gMSA)**: Can be used across multiple computers, preferred solution

#### Security Recommendation

1. **Use gMSAs Where Possible**:
   - Replace traditional service accounts with gMSAs
   - Prioritize high-privilege service accounts
   - Plan migration for legacy applications

2. **Implementation Requirements**:
   - At least one Windows Server 2012 or later domain controller
   - KDS root key must be created (one-time operation)
   - Applications must support gMSA authentication

3. **Best Practices**:
   - Use gMSAs for all new service deployments
   - Create separate gMSAs for different services
   - Document gMSA usage and permissions
   - Regular audit of gMSA deployments

#### How the Test Works

This test counts managed service accounts in Active Directory and categorizes them by:
- Total MSAs and gMSAs
- Group vs. standalone MSAs
- Account details and status

#### Related Tests

- `Test-MtAdUserKnownServiceAccountCount` - Traditional service account identification
- `Test-MtAdKdsRootKeysCount` - KDS root key requirement for gMSAs
- `Test-MtAdUserPasswordNeverExpiresCount` - Traditional accounts with non-expiring passwords

#### References

- [Microsoft: Group Managed Service Accounts Overview](https://docs.microsoft.com/en-us/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)
- [Microsoft: Getting Started with gMSAs](https://docs.microsoft.com/en-us/windows-server/security/group-managed-service-accounts/getting-started-with-group-managed-service-accounts)

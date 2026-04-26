#### Test-MtAdUserSpnDomainAdminCount

#### Why This Test Matters

Domain administrator accounts with SPNs represent the **highest possible Kerberoasting risk**:

- **Maximum privileges**: Domain admins have unrestricted access to the entire domain
- **Golden ticket risk**: Compromising a domain admin can lead to complete domain compromise
- **Service account misuse**: Domain admin accounts should never be used as service accounts
- **Password exposure**: SPNs enable offline password cracking attempts

**Zero domain admin accounts should have SPNs configured.**

#### Security Recommendation

If domain admin accounts have SPNs:
- **Immediate action**: Remove all SPNs from domain admin accounts
- **Investigate**: Determine why SPNs were configured
- **Migrate services**: Move services to dedicated service accounts or gMSAs
- **Audit**: Review who has domain admin privileges
- **Monitor**: Implement alerts for SPN changes to privileged accounts

#### How the Test Works

This test identifies domain administrator accounts (using the well-known RID 500) and checks if they have any SPNs configured. Any SPNs found on these accounts are flagged as critical security risks.

#### Related Tests

- `Test-MtAdUserSpnDomainAdminDetails` - Detailed SPN information for domain admins
- `Test-MtAdUserSpnTotalCount` - Overall user SPN count
- `Test-MtAdUserSpnServiceClassCount` - Service classes on user accounts

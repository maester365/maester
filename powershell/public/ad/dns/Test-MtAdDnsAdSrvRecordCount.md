#### Test-MtAdDnsAdSrvRecordCount

#### Why This Test Matters

SRV records are essential for Active Directory service location. They enable clients to find:

- **Domain controllers** (_ldap records)
- **Global Catalog servers** (_gc records)
- **Kerberos services** (_kerberos records)
- **Password change services** (_kpasswd records)

Missing or incorrect SRV records can prevent:
- Domain join operations
- Authentication
- Group Policy application
- Service discovery

#### Security Recommendation

- Monitor SRV record counts for unexpected changes
- Verify SRV records point to authorized domain controllers only
- Protect DNS zones containing SRV records from unauthorized modification
- Regularly test service location from client perspectives

#### How the Test Works

This test counts SRV records used by Active Directory Domain Services, including _ldap, _gc, _kerberos, and _kpasswd service records.

#### Related Tests

- `Test-MtAdDnsAdSrvRecordDetails` - Provides detailed SRV record information

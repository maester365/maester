The forest functional level determines which Active Directory features are available across all domains in the forest. Higher functional levels unlock important forest-wide security capabilities:

- **Windows Server 2016+**: Enables features like privileged access management (PAM) across the forest
- **Windows Server 2012 R2+**: Provides access to forest-wide authentication policies and silos
- **Global Features**: Some features require forest-wide consistency to function
- **Security Posture**: Running at lower levels means missing modern security features

#### Security Recommendation

Aim to maintain your forest at the highest functional level supported by all domain controllers:

1. **Verify Compatibility**: Ensure all DCs in all domains support the target level
2. **Test Applications**: Verify critical applications work at the higher level
3. **Plan Maintenance Window**: Schedule the upgrade appropriately
4. **Document Changes**: Record the upgrade for audit and compliance purposes

#### How the Test Works

This test retrieves the current forest functional level from Active Directory along with basic forest information including the root domain and domain count.

#### Related Tests

- `Test-MtAdDomainFunctionalLevel` - Retrieves the domain functional level
- `Test-MtAdForestDomainCount` - Counts domains in the forest

#### Related links

- [Microsoft Learn: Active Directory Domain Services functional levels](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels)
- [ANSSI Active Directory checkpoints: Insufficient forest and domains functional levels](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_functional_level)

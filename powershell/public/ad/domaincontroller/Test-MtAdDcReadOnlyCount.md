#### Test-MtAdDcReadOnlyCount

#### Why This Test Matters

Read-Only Domain Controllers (RODCs) are a critical security feature introduced in Windows Server 2008 designed specifically for deployment in locations where physical security cannot be guaranteed, such as branch offices. RODCs provide several security benefits:

- **Reduced attack surface**: RODCs maintain a read-only copy of the Active Directory database, preventing directory modifications from compromised locations
- **Credential caching control**: Administrators can configure which credentials (if any) are cached on the RODC, limiting exposure if the server is compromised
- **Read-only DNS**: RODCs can host read-only DNS zones, reducing DNS poisoning risks
- **Filtered attribute set**: Sensitive attributes can be prevented from replicating to RODCs

Understanding your RODC deployment helps ensure:
- Appropriate placement in less secure locations
- Proper credential caching policies
- Compliance with security standards for branch office infrastructure

#### Security Recommendation

1. **Deploy RODCs in branch offices**: Use RODCs instead of writable DCs in locations with limited physical security
2. **Configure credential caching**: Limit cached credentials to only those needed for local operations
3. **Monitor RODC replication**: Regularly audit what data is being replicated to RODCs
4. **Plan for RODC compromise**: Have procedures in place for quickly resetting passwords if an RODC is compromised
5. **Review RODC placement**: Ensure all RODCs are justified and necessary

#### How the Test Works

This test retrieves all domain controllers and identifies which are configured as Read-Only Domain Controllers. The test reports:

- Total number of domain controllers
- Number of writable domain controllers
- Number of read-only domain controllers (RODCs)
- Names and sites of RODCs (if any exist)

#### Related Tests

- `Test-MtAdDcNonGlobalCatalogCount` - Checks Global Catalog configuration
- `Test-MtAdDcSiteCoverageCount` - Analyzes DC distribution across sites
- `Test-MtAdSiteWithoutDcCount` - Identifies sites without DC coverage

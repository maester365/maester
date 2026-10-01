#### Test-MtAdTrustTotalCount

#### Why This Test Matters

Domain trusts are critical security boundaries in Active Directory environments. Understanding the number and configuration of trusts is essential for:

- **Security Assessment**: Knowing how many external entities can authenticate in your environment
- **Attack Surface Management**: Each trust represents a potential attack vector that needs monitoring
- **Compliance Reporting**: Many frameworks require documentation of trust relationships
- **Operational Visibility**: Understanding cross-domain authentication paths

Trusts allow users from one domain to access resources in another. While necessary for multi-domain environments, unnecessary or misconfigured trusts can create security vulnerabilities.

#### Security Recommendation

- **Inventory**: Maintain an inventory of all trust relationships and their purposes
- **Regular Review**: Periodically review trusts to ensure they are still needed
- **Documentation**: Document the business justification for each trust
- **Monitoring**: Monitor trust validation status and authentication events
- **Principle of Least Privilege**: Only create trusts when absolutely necessary

#### How the Test Works

This test retrieves all trust objects from Active Directory using `Get-ADTrust` and counts the total number of configured trusts. The test returns:

- Total count of trusts
- Informational result (no pass/fail criteria)

#### Related Tests

- `Test-MtAdTrustInterForestCount` - Identifies external/inter-forest trusts
- `Test-MtAdTrustQuarantinedCount` - Checks for SID filtering on trusts
- `Test-MtAdTrustStaleCount` - Identifies trusts not validated recently
- `Test-MtAdTrustDetails` - Provides detailed trust configuration information

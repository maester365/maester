#### Test-MtAdTrustInterForestCount

#### Why This Test Matters

Inter-forest trusts (external trusts) connect different Active Directory forests and pose unique security risks:

- **SID History Attacks**: External trusts may be vulnerable to SID history attacks where attackers inject privileged SIDs from the external domain
- **Less Visibility**: You have less control and visibility over security practices in external forests
- **Lateral Movement**: Compromised external domains can be used as pivot points for attacks
- **Trust Transitivity**: Understanding which trusts are external helps assess blast radius

Intra-forest trusts (within the same forest) generally have stronger security guarantees because they share a common schema and configuration.

#### Security Recommendation

- **Minimize External Trusts**: Only create inter-forest trusts when absolutely necessary
- **Enable SID Filtering**: Always enable SID filtering (quarantine) on external trusts
- **Selective Authentication**: Consider using selective authentication for external trusts
- **Regular Review**: Review external trusts quarterly to ensure they are still required
- **Monitor Closely**: Enable enhanced logging for authentication events across external trusts
- **Documentation**: Maintain detailed documentation of why each external trust exists

#### How the Test Works

This test analyzes all trust objects and identifies those where `IntraForest` is `$false`. The test returns:

- Total count of trusts
- Count of inter-forest trusts
- Count of intra-forest trusts

#### Related Tests

- `Test-MtAdTrustQuarantinedCount` - Checks if external trusts have SID filtering enabled
- `Test-MtAdTrustNonQuarantinedDetails` - Lists external trusts without SID filtering
- `Test-MtAdTrustTotalCount` - Overall trust count
- `Test-MtAdTrustDetails` - Detailed trust configuration

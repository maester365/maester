# Test-MtAdCrossForestReferencesCount

## Why This Test Matters

Cross-forest references represent security principals (users, groups, computers) from trusted external forests that have been granted access to resources in the local forest. Understanding cross-forest references is critical for:

- **Trust Management**: Cross-forest references indicate active trust relationships that must be monitored and maintained
- **Security Boundaries**: External forest references expand the security boundary beyond the local forest
- **Access Control**: References from external forests may have access to local resources; these must be regularly audited
- **Compliance**: Many compliance frameworks require documentation and monitoring of cross-forest access
- **Risk Assessment**: Unknown or unexpected cross-forest references could indicate security compromise or misconfiguration

## Security Recommendation

If cross-forest references exist:

1. **Inventory and Document**: Maintain an inventory of all cross-forest references and their purposes
2. **Regular Review**: Review cross-forest references quarterly to ensure they are still needed
3. **Trust Verification**: Verify that trusts with external forests are still required and properly secured
4. **Access Audit**: Audit what resources cross-forest principals can access in the local forest
5. **Monitor for Changes**: Set up alerting for new cross-forest references, which could indicate unauthorized access provisioning

## How the Test Works

This test retrieves cross-forest reference information from the forest configuration using `Get-ADForest`. It counts the number of cross-forest references and reports whether any external forest principals have been granted access to local resources.

## Related Tests

- `Test-MtAdTrustTotalCount` - Checks for configured domain trusts
- `Test-MtAdTrustDetails` - Provides detailed trust configuration information

# Test-MtAdDomainControllerCount

## Why This Test Matters

Understanding the number and distribution of domain controllers in your domain is critical for:

- **High Availability**: Ensuring sufficient DCs exist to handle authentication load and provide redundancy
- **Disaster Recovery**: Knowing how many DCs need to be recovered in a disaster scenario
- **Site Coverage**: Verifying that all sites have appropriate DC coverage for local authentication
- **Capacity Planning**: Determining if additional DCs are needed based on user and computer growth

## Security Recommendation

- **Minimum Redundancy**: Maintain at least 2 DCs per domain for fault tolerance
- **Geographic Distribution**: Place DCs strategically across sites to ensure local authentication
- **RODC Consideration**: Consider Read-Only Domain Controllers (RODC) for branch offices
- **Regular Monitoring**: Track DC health and availability as part of your security monitoring

## How the Test Works

This test retrieves all domain controllers from Active Directory and counts them. It also lists the names of all DCs for easy reference.

## Related Tests

- `Test-MtAdDomainFunctionalLevel` - Retrieves the domain functional level
- `Test-MtAdForestDomainCount` - Counts domains in the forest

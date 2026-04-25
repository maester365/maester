# Test-MtAdDcSiteCoverageCount

## Why This Test Matters

Active Directory sites are used to define the physical topology of your network and optimize authentication traffic. Understanding site coverage helps ensure:

- **Geographic redundancy**: Authentication services are available in all locations
- **Network efficiency**: Clients authenticate to the nearest DC
- **Disaster recovery**: Multiple sites provide failover capabilities
- **Capacity planning**: Proper distribution of DCs across sites

Sites without domain controllers may indicate:
- Hub-and-spoke topology where remote sites rely on central DCs
- Misconfigured site topology
- Missing DCs in satellite offices

## Security Recommendation

Review your site topology regularly to ensure all locations have adequate DC coverage. Consider placing at least one DC in each major geographic location to ensure authentication resilience.

## How the Test Works

This test retrieves all domain controllers and counts the unique sites that contain at least one DC. It compares this to the total number of sites in the domain.

## Related Tests

- `Test-MtAdDomainControllerCount` - Total count of domain controllers
- `Test-MtAdDcOperatingSystemDetails` - DC OS distribution information

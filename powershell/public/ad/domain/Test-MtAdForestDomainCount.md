# Test-MtAdForestDomainCount

## Why This Test Matters

Understanding the number and names of domains in your forest is critical for:

- **Security Boundaries**: Each domain represents a security boundary with its own policies
- **Trust Management**: Understanding trust relationships between domains
- **Administrative Scope**: Knowing where administrative permissions apply
- **Compliance Scope**: Determining the scope of compliance assessments
- **Disaster Recovery**: Planning recovery procedures across all domains

## Security Recommendation

- **Minimize Domains**: Fewer domains reduce complexity and attack surface
- **Document Structure**: Maintain documentation of all domains and their purposes
- **Review Regularly**: Periodically review if all domains are still needed
- **Consistent Policies**: Apply consistent security policies across all domains

## How the Test Works

This test retrieves all domains from the Active Directory forest and counts them. It also lists all domain names for reference.

## Related Tests

- `Test-MtAdForestFunctionalLevel` - Retrieves the forest functional level
- `Test-MtAdDomainControllerCount` - Counts domain controllers in the current domain

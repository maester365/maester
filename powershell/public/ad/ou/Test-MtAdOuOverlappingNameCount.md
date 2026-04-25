# Test-MtAdOuOverlappingNameCount

## Why This Test Matters

Organizational Units with overlapping (duplicate) names can create administrative confusion and operational risks in Active Directory:

- **Administrative errors**: Administrators may inadvertently apply Group Policies, permissions, or settings to the wrong OU when multiple OUs share the same name
- **Scripting complications**: Automation scripts that reference OUs by name may target incorrect containers
- **Policy application issues**: Group Policy links may be applied to unintended OUs
- **Audit confusion**: Security audits and compliance reports become harder to interpret when OU names are ambiguous

While Active Directory technically allows duplicate OU names (as long as they're in different locations), this practice should be minimized to reduce operational risk.

## Security Recommendation

Review OUs with duplicate names and consider renaming them to be more descriptive and unique. Use naming conventions that incorporate location, function, or department to make OU names unambiguous. For example:

- Instead of multiple "Users" OUs, use "NYC-Users", "LA-Users", "London-Users"
- Instead of multiple "Servers" OUs, use "Production-Servers", "Test-Servers", "Dev-Servers"

## How the Test Works

This test retrieves all Organizational Units from Active Directory and:
- Groups OUs by their Name property
- Identifies names that appear more than once
- Counts the number of duplicate name groups
- Lists all OUs that share names with other OUs

## Related Tests

- `Test-MtAdOuAtDomainRootCount` - Analyzes OU structure at the domain root level
- `Test-MtAdOuEmptyCount` - Identifies OUs that contain no objects

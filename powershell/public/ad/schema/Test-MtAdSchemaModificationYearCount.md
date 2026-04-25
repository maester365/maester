# Test-MtAdSchemaModificationYearCount

## Why This Test Matters

Understanding when your Active Directory schema has been modified provides important visibility into the evolution of your directory infrastructure. Schema modifications typically occur during:

- **Domain upgrades**: When upgrading to newer Windows Server versions
- **Application installations**: Products like Exchange, Skype for Business, and third-party applications extend the schema
- **Custom developments**: Organizations may add custom attributes or classes

Tracking schema modification years helps:
- **Audit trail**: Understand when major changes occurred
- **Compliance**: Document directory evolution for compliance purposes
- **Troubleshooting**: Correlate issues with schema change timeframes
- **Planning**: Identify when the directory was last updated

## Security Recommendation

While schema modifications are normal and necessary, they should be:
- **Documented**: All schema changes should be recorded with business justification
- **Planned**: Schema changes should go through change control processes
- **Tested**: Schema extensions should be tested in a lab environment first
- **Authorized**: Only privileged administrators should have schema admin rights

## How the Test Works

This test retrieves all schema objects and analyzes their creation dates to identify:
- How many different years have had schema modifications
- The total number of schema objects
- The first and most recent schema changes

## Related Tests

- `Test-MtAdSchemaModificationYearDetails` - Provides detailed breakdown by year
- `Test-MtAdSchemaVersionEntryCount` - Shows the current schema version
- `Test-MtAdSchemaVersionDetails` - Provides comprehensive schema information

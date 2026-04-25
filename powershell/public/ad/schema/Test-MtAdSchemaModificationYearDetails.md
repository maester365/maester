# Test-MtAdSchemaModificationYearDetails

## Why This Test Matters

Detailed visibility into schema modifications by year provides a comprehensive timeline of your Active Directory's evolution. This information is valuable for:

- **Capacity planning**: Understanding growth patterns of the directory
- **Change management**: Tracking when major applications were deployed
- **Security auditing**: Identifying unauthorized or unexpected schema changes
- **Compliance reporting**: Documenting directory modifications for auditors

Unexpected spikes in schema modifications may indicate:
- Unauthorized application deployments
- Malicious schema extensions
- Improper testing procedures
- Lack of change control

## Security Recommendation

Establish monitoring for schema changes:
- **Alert on schema modifications**: Configure alerts when schema changes occur
- **Regular reviews**: Periodically review schema modification history
- **Access controls**: Limit Schema Admins group membership
- **Audit logging**: Enable auditing for schema changes

## How the Test Works

This test analyzes schema objects and groups them by creation year, providing:
- Count of schema objects created per year
- Percentage distribution across years
- Timeline of directory evolution

## Related Tests

- `Test-MtAdSchemaModificationYearCount` - Shows count of years with modifications
- `Test-MtAdSchemaVersionEntryCount` - Shows current schema version
- `Test-MtAdSchemaVersionDetails` - Provides comprehensive schema details

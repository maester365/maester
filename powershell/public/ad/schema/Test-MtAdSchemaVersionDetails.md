#### Test-MtAdSchemaVersionDetails

#### Why This Test Matters

Comprehensive schema information provides the foundation for understanding your Active Directory infrastructure. The schema defines:

- **Object classes**: What types of objects can exist (users, computers, groups)
- **Attributes**: What properties objects can have
- **Constraints**: Rules for object creation and modification

Understanding schema details helps with:
- **Troubleshooting**: Identifying schema-related issues
- **Planning**: Preparing for application deployments
- **Documentation**: Maintaining accurate AD documentation
- **Security**: Detecting unauthorized schema modifications

#### Security Recommendation

Protect your schema with these practices:
- **Schema Admins group**: Keep membership minimal and monitored
- **Change control**: Require approval for all schema modifications
- **Documentation**: Maintain records of all schema extensions
- **Backup**: Regularly backup the schema NC (naming context)
- **Monitoring**: Alert on any schema modifications

#### How the Test Works

This test retrieves detailed information from the schema container including:
- Schema version number
- Corresponding Windows Server version
- Schema creation and modification dates
- Distribution of object classes
- Total schema object count

#### Related Tests

- `Test-MtAdSchemaVersionEntryCount` - Shows schema version number
- `Test-MtAdSchemaModificationYearCount` - Shows modification timeline
- `Test-MtAdSchemaModificationYearDetails` - Detailed modification breakdown

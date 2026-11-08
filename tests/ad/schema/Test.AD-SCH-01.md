Understanding when Active Directory schema objects were created provides visibility into the evolution of your directory infrastructure. This inventory groups objects by `whenCreated`, not by a modification date; it does not establish an audit history of subsequent changes. Schema extensions typically occur during:

- **Domain upgrades**: When upgrading to newer Windows Server versions
- **Application installations**: Products like Exchange, Skype for Business, and third-party applications extend the schema
- **Custom developments**: Organizations may add custom attributes or classes

Tracking schema object creation years helps:
- **Inventory**: Understand when extensions first appeared (not later edits)
- **Compliance**: Document directory evolution for compliance purposes
- **Troubleshooting**: Correlate issues with schema change timeframes
- **Planning**: Identify when objects were first created

#### Control Type

**Operational**

#### Security Recommendation

While schema modifications are normal and necessary, they should be:
- **Documented**: All schema changes should be recorded with business justification
- **Planned**: Schema changes should go through change control processes
- **Tested**: Schema extensions should be tested in a lab environment first
- **Authorized**: Only privileged administrators should have schema admin rights

#### How the Test Works

This test retrieves all schema objects and analyzes their creation dates to identify:
- How many different years had schema objects created
- The total number of schema objects
- A count for each year and details of every schema object with a creation date

#### Related Tests

- **AD-SCH-03 — Schema version and class definitions should be investigated** — `Test-MtAdSchemaVersionEntryCount` — Reviews schema version and class definitions.

<!--- Results --->
%TestResult%

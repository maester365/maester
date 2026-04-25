# Test-MtAdOuEmptyDetails

## Why This Test Matters

Understanding which specific Organizational Units are empty is essential for directory maintenance and cleanup efforts. This detailed view helps administrators:

- **Plan cleanup activities**: Identify specific OUs that can be evaluated for deletion
- **Assess creation dates**: Determine if empty OUs are recent (possibly in use) or old (likely abandoned)
- **Coordinate with teams**: Share specific OU names with relevant administrators for verification
- **Track cleanup progress**: Document which empty OUs have been reviewed and acted upon

The detailed list enables targeted cleanup efforts rather than broad, unfocused maintenance activities.

## Security Recommendation

Use this detailed information to conduct a systematic review of empty OUs:

1. **Review with stakeholders**: Share the list with department administrators who may know if an OU is needed
2. **Check creation dates**: Older empty OUs are more likely candidates for deletion
3. **Verify Group Policy links**: Empty OUs with linked GPOs may still serve a purpose
4. **Document decisions**: Record why certain empty OUs are retained
5. **Schedule deletions**: Plan removal of confirmed-unused OUs during maintenance windows

Establish a process where new OUs are documented at creation time to prevent future accumulation of empty, undocumented containers.

## How the Test Works

This test retrieves all Organizational Units from Active Directory and:
- Identifies OUs with no user, group, or computer objects
- Lists each empty OU with its name, creation date, and distinguished name
- Provides a complete inventory of empty containers for cleanup planning

## Related Tests

- `Test-MtAdOuEmptyCount` - Provides count summary of empty OUs
- `Test-MtAdOuStaleCount` - Identifies OUs not modified since before 2020
- `Test-MtAdGroupEmptyNonPrivilegedDetails` - Lists empty non-privileged groups

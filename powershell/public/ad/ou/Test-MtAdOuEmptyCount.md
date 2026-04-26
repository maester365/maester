#### Test-MtAdOuEmptyCount

#### Why This Test Matters

Empty Organizational Units (OUs that contain no users, groups, or computers) represent directory clutter that can:

- **Create confusion**: Administrators may wonder if the OU has a purpose or if it can be deleted
- **Complicate navigation**: Empty OUs make the directory structure harder to browse and understand
- **Accumulate over time**: OUs created for temporary purposes or abandoned projects often remain indefinitely
- **Impact Group Policy**: Empty OUs with linked GPOs may still be processed during policy refresh

While empty OUs don't pose a direct security risk, they indicate opportunities for directory cleanup and maintenance. Regular cleanup of empty OUs helps maintain an organized, efficient directory structure.

#### Security Recommendation

Periodically review and clean up empty Organizational Units:
- Identify OUs that serve no current purpose
- Check if empty OUs have Group Policy links that should be removed
- Verify that empty OUs aren't placeholders for future use
- Document any empty OUs that should be retained and why
- Delete empty OUs that are no longer needed

Consider establishing a regular cleanup schedule (quarterly or annually) to keep the directory organized.

#### How the Test Works

This test retrieves all Organizational Units from Active Directory and:
- Checks each OU for the presence of user objects
- Checks each OU for the presence of group objects
- Checks each OU for the presence of computer objects
- Counts OUs that contain none of these object types
- Reports the percentage of OUs that are empty

#### Related Tests

- `Test-MtAdOuEmptyDetails` - Provides detailed list of all empty OUs
- `Test-MtAdOuStaleCount` - Identifies OUs not modified since before 2020
- `Test-MtAdGroupEmptyNonPrivilegedCount` - Identifies empty non-privileged groups

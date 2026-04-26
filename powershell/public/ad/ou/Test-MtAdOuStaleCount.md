#### Test-MtAdOuStaleCount

#### Why This Test Matters

- Organizational Units that haven't been modified since before 2020 may represent:
- Abandoned projects: OUs created for initiatives that were never completed or were abandoned
- Outdated structure: Organizational units that no longer reflect current business structure
- Directory clutter: Unused containers that make the directory harder to navigate
- Potential security gaps: Stale OUs may have outdated permissions or Group Policy links
- While stale OUs don't pose a direct security threat, they contribute to directory sprawl and can make administration more complex. They may also retain old permissions or Group Policy settings that are no longer appropriate.

#### Security Recommendation
- Regularly review OUs that haven't been modified in several years:
- Verify whether the OU is still needed for its original purpose
- Check if the OU contains any objects (see `Test-MtAdOuEmptyCount`)
- Review permissions and Group Policy links on stale OUs
- Consider deleting or repurposing OUs that are no longer needed
- Document the purpose of OUs to help future cleanup efforts

#### How the Test Works

- This test retrieves all Organizational Units from Active Directory and:
- Examines the last modified timestamp of each OU
- Counts OUs that haven't been modified since before January 1, 2020
- Lists stale OUs with their last modification date and distinguished name

#### Related Tests
- `Test-MtAdOuEmptyCount` - Identifies OUs with no objects
- `Test-MtAdOuEmptyDetails` - Provides detailed list of empty OUs
- `Test-MtAdGroupStaleCount` - Identifies groups not modified since before 2020

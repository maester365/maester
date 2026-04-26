#### Test-MtAdComputerCreatorSidCount

#### Why This Test Matters

The `ms-ds-CreatorSid` attribute identifies which security principal created a computer account. This is valuable for:

- **Audit trail**: Understanding who or what created computer accounts helps trace unauthorized additions
- **Delegation analysis**: Identifying service accounts or users with excessive computer creation rights
- **Security monitoring**: Detecting unusual computer creation patterns that may indicate compromise
- **Compliance**: Meeting requirements for tracking resource creation in the directory

#### Security Recommendation

Computer account creation should be tightly controlled:
- Limit the `ms-DS-MachineAccountQuota` attribute (default is 10) to prevent standard users from creating computer accounts
- Use dedicated service accounts for automated computer provisioning
- Regularly audit computer accounts to identify those created by unexpected principals
- Consider setting the quota to 0 and using pre-staged computer accounts or dedicated provisioning processes

#### How the Test Works

This test counts computer objects that have the `ms-ds-CreatorSid` attribute populated. This attribute is typically set when:
- A user or service account explicitly creates a computer account
- The creating principal has been captured in the directory

Note: Not all computer accounts will have this attribute, depending on how they were created.

#### Related Tests

- `Test-MtAdComputerNonStandardGroup` - Identifies computers with unusual primary group assignments
- `Test-MtAdComputerInDefaultContainer` - Finds computers that may have been auto-created

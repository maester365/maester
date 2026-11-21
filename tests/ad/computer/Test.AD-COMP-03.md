The `ms-ds-CreatorSid` attribute identifies which security principal created a computer account. This is valuable for:

- **Audit trail**: Understanding who or what created computer accounts helps trace unauthorized additions
- **Delegation analysis**: Identifying service accounts or users with excessive computer creation rights
- **Security monitoring**: Detecting unusual computer creation patterns that may indicate compromise
- **Compliance**: Meeting requirements for tracking resource creation in the directory

#### Control Type

**Detective**

#### Security Recommendation

Computer account creation should be tightly controlled:
- Limit the `ms-DS-MachineAccountQuota` attribute (default is 10) to prevent standard users from creating computer accounts
- Use dedicated service accounts for automated computer provisioning
- Regularly audit computer accounts to identify those created by unexpected principals
- Consider setting the quota to 0 and using pre-staged computer accounts or dedicated provisioning processes

#### How the Test Works

The cached LDAP computer collector retrieves `mS-DS-CreatorSID` as `CreatorSid`. This check reports **Investigate** because a recorded creator is not proof of an unauthorized join. It does not report a zero count when the field was not collected. This test counts enabled computer objects that have the attribute populated. This attribute is typically set when:
- A user or service account explicitly creates a computer account
- The creating principal has been captured in the directory

Note: Not all computer accounts will have this attribute, depending on how they were created.

#### Related Tests

- [AD-COMP-04 — Enabled computers should use standard primary groups](https://maester.dev/docs/tests/AD-COMP-04): Reviews a separate computer-account attribute that can reveal unexpected configuration.
- [AD-COMP-06 — Enabled computers should be moved out of the default Computers container](https://maester.dev/docs/tests/AD-COMP-06): Identifies computers left in the default container, which can provide context when reviewing how accounts were provisioned.

<!--- Results --->
%TestResult%

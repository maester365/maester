The LDAP `mS-DS-CreatorSID` attribute can record a computer account's creator in some account-creation paths. The cached collector exposes the raw `mS-DS-CreatorSID` field and a compatible `CreatorSid` alias. Its presence is useful for investigation, not proof of an unauthorized join. This is valuable for:

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

The cached LDAP computer collector retrieves raw `mS-DS-CreatorSID` and exposes the compatible `CreatorSid` alias. This check reports **Investigate** because a recorded creator is not proof of an unauthorized join. It does not report zero when the attribute was not collected. The check counts enabled computers with a visible value; a missing value is not proof no creator existed. This attribute can be set when:
- A user or service account explicitly creates a computer account
- The creating principal has been captured in the directory

Note: Not all computer accounts will have this attribute, depending on how they were created.

#### Related Tests

- **AD-COMP-04 — Enabled computers should use standard primary groups** — `Test-MtAdComputerNonStandardGroup` — Reviews nonstandard primary-group assignments.
- **AD-COMP-06 — Enabled computers should be moved out of the default Computers container** — `Test-MtAdComputerInDefaultContainer` — Reviews default-container placement, not creator identity.

<!--- Results --->
%TestResult%

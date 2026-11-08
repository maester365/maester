Allow ACEs that grant `GenericAll`, `WriteDacl`, `WriteOwner`, or `ExtendedRight` can enable high-impact control over Active Directory objects. These permissions are commonly involved in privilege escalation and persistence paths.

- **GenericAll**: Grants broad control over the object.
- **WriteDacl / WriteOwner**: Enables permission tampering or ownership takeover.
- **ExtendedRight**: May allow sensitive control-access operations depending on object type.

#### Control Type

**Operational**

#### Remediation action

Limit privileged rights to tightly controlled administrative groups. Investigate unexpected identities or objects that accumulate these permissions.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters allow ACEs for `GenericAll`, `WriteDacl`, `WriteOwner`, or `ExtendedRight`, reports aggregate counts and lists each affected object's ACE count, identities and matched rights. These rights require human review; their presence alone is not a failure.

#### Related Tests

- `Test-MtAdDaclPrivilegedExtendedRightCount`
- `Test-MtAdDaclDistinctIdentityCount`

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

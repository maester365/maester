Extended rights control specific privileged operations in Active Directory, such as sensitive control-access permissions tied to object classes or administrative workflows. Understanding how often they are delegated helps surface potentially risky permission models.

- **Sensitive Operations**: Some extended rights can enable password resets, replication access, or other administrative actions.
- **Delegation Mapping**: Counting these ACEs helps you understand how broadly control-access permissions are assigned.
- **Scope Awareness**: Distinct `ObjectType` values show how granular or broad the delegation is.

#### Control Type

**Operational**

#### Remediation action

Review principals granted extended rights and verify that those delegations are necessary, documented, and limited to the smallest practical scope.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters allow ACEs whose rights include `ExtendedRight` (including combined rights), reports counts across identities, objects and object types, lists counts by `ObjectType` GUID, then lists identities granted specifically named sensitive rights such as password reset or replication. A blank or all-zero GUID is counted as `All / Not specified` but is not assigned a named right. All findings are for review, not automatic failures.

#### Related Tests

- `Test-MtAdDaclPrivilegedAllowAceCount`

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

#### Test-MtAdDaclPrivilegedExtendedRightCount

#### Why This Test Matters

Extended rights control specific privileged operations in Active Directory, such as sensitive control-access permissions tied to object classes or administrative workflows. Understanding how often they are delegated helps surface potentially risky permission models.

- **Sensitive Operations**: Some extended rights can enable password resets, replication access, or other administrative actions.
- **Delegation Mapping**: Counting these ACEs helps you understand how broadly control-access permissions are assigned.
- **Scope Awareness**: Distinct `ObjectType` values show how granular or broad the delegation is.

#### Security Recommendation

Review principals granted extended rights and verify that those delegations are necessary, documented, and limited to the smallest practical scope.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters to allow ACEs whose `ActiveDirectoryRights` includes `ExtendedRight`, and reports counts across identities, objects, and object types.

#### Related Tests

- `Test-MtAdDaclPrivilegedExtendedRightDetails`
- `Test-MtAdDaclPrivilegedAllowAceCount`
- `Test-MtAdDaclPrivilegedAllowAceDetails`

#### Test-MtAdDaclPrivilegedAllowAceDetails

#### Why This Test Matters

A count alone does not show where powerful ACEs are applied. Grouping privileged allow ACEs by object helps identify high-value directory objects that carry sensitive delegated rights.

- **Object-Centric Review**: Highlights which objects hold the most powerful ACEs.
- **Delegation Validation**: Makes it easier to confirm whether privileged rights are intentional.
- **Attack Path Awareness**: Sensitive permissions on administrative objects can enable escalation.

#### Security Recommendation

Review objects with privileged allow ACEs and confirm the assigned identities and rights are justified. Reduce direct assignments where possible and prefer auditable group-based delegation.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters to allow ACEs containing `GenericAll`, `WriteDacl`, `WriteOwner`, or `ExtendedRight`, and groups the results by object.

#### Related Tests

- `Test-MtAdDaclPrivilegedAllowAceCount`
- `Test-MtAdDaclIdentityAceDistribution`
- `Test-MtAdDaclPrivilegedExtendedRightDetails`

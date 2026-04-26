#### Test-MtAdDaclNonInheritedAceCount

#### Why This Test Matters

Non-inherited ACEs represent explicit access assignments applied directly to directory objects.

- **Custom delegation visibility**: Explicit ACEs often reveal manual delegations and exceptions
- **Misconfiguration detection**: Direct permissions are more likely to diverge from baseline inheritance
- **Review prioritization**: Objects with many explicit ACEs deserve closer security review

#### Security Recommendation

- Review why explicit permissions were added instead of relying on inheritance
- Remove unnecessary one-off ACEs and standardize delegations where possible
- Pay special attention to explicit ACEs on privileged containers and administrative objects

#### How the Test Works

This test reads `$adState.DaclEntries` and counts entries where `IsInherited` is `$false`.

#### Related Tests

- `Test-MtAdDaclDenyAceCount` - Counts deny ACEs in DACLs
- `Test-MtAdDaclPrivilegedAllowAceCount` - Counts privileged allow authorizations
- `Test-MtAdDaclUnresolvedSidCount` - Identifies stale SID references in ACEs

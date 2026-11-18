Non-inherited ACEs represent explicit access assignments applied directly to directory objects.

- **Custom delegation visibility**: Explicit ACEs often reveal manual delegations and exceptions
- **Misconfiguration detection**: Direct permissions are more likely to diverge from baseline inheritance
- **Review prioritization**: Objects with many explicit ACEs deserve closer security review

#### Control Type

**Operational**

#### Security Recommendation

- Review why explicit permissions were added instead of relying on inheritance
- Remove unnecessary one-off ACEs and standardize delegations where possible
- Pay special attention to explicit ACEs on privileged containers and administrative objects

#### How the Test Works

This test reads `$adState.DaclEntries` and counts entries where `IsInherited` is `$false`.

#### Related Tests

- **AD-DACL-05 — Deny ACEs and affected identities should be investigated** — `Test-MtAdDaclDenyAceCount` — Counts deny ACEs in DACLs.
- **AD-DACL-09 — Privileged allow ACEs and affected objects should be investigated** — `Test-MtAdDaclPrivilegedAllowAceCount` — Counts privileged allow authorizations.
- **AD-DACL-15 — Unresolved SID counts and affected objects should be investigated** — `Test-MtAdDaclUnresolvedSidCount` — Identifies stale SID references in ACEs.

> **Note:** This test is `LongRunning`. It loads the full DACL dataset, which can consume significant memory in large Active Directory environments. Use `Invoke-Maester -IncludeLongRunning` to run it.

<!--- Results --->
%TestResult%

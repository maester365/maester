#### Test-MtAdDaclPrivilegedExtendedRightDetails

#### Why This Test Matters

Extended rights are most useful when you can see which specific `ObjectType` values are being delegated. Grouping ACEs by GUID reveals whether permissions are narrowly targeted or broadly applied.

- **GUID-Level Visibility**: Highlights which extended-right object types occur most often.
- **Delegation Review**: Helps correlate control-access permissions with documented administration patterns.
- **Change Tracking**: Makes it easier to compare extended-right usage over time.

#### Security Recommendation

Document the purpose of delegated extended rights and review object types with high counts or unexpected identity coverage.

#### How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters to allow ACEs containing `ExtendedRight`, normalizes missing `ObjectType` values, and groups the results by `ObjectType`.

#### Related Tests

- `Test-MtAdDaclPrivilegedExtendedRightCount`
- `Test-MtAdDaclPrivilegedAllowAceDetails`
- `Test-MtAdDaclIdentityAceDistribution`

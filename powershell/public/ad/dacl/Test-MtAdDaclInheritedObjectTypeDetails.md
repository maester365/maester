# Test-MtAdDaclInheritedObjectTypeDetails

## Why This Test Matters

Inherited object type detail helps explain where inheritable ACEs are intended to apply.

- **Scoping transparency**: Reveals which descendant object classes are targeted most often
- **Delegation review**: Helps validate whether inherited permissions are narrowly or broadly applied
- **Troubleshooting support**: Useful when investigating unexpected effective permissions on child objects

## Security Recommendation

- Review heavily used inherited object type targets for overly broad delegations
- Confirm that inherited ACE scope matches intended administrative boundaries
- Reassess inherited rights on sensitive containers if descendant object targeting is not well understood

## How the Test Works

This test reads `$adState.DaclEntries`, filters out the all-zero `InheritedObjectType` value, and groups the remaining ACEs by inherited object type GUID.

## Related Tests

- `Test-MtAdDaclInheritedObjectTypeCount` - Counts distinct inherited object type GUIDs
- `Test-MtAdDaclPrivilegedExtendedRightIdentity` - Shows identities with privileged extended rights
- `Test-MtAdDaclUnresolvedSidDetails` - Lists objects containing orphaned SID ACEs

# Test-MtAdDaclInheritedObjectTypeCount

## Why This Test Matters

Inherited object type GUIDs define which descendant object classes an inheritable ACE targets.

- **Delegation scope visibility**: Helps show how precisely ACE inheritance is scoped
- **Privilege impact analysis**: Broad inheritance can extend powerful rights to many child objects
- **Configuration review**: Distinct inherited object types reveal the variety of object classes affected by delegations

## Security Recommendation

- Review inherited ACEs that target sensitive descendant object classes
- Prefer precise scoping over overly broad inheritance where possible
- Validate that inheritance design matches your delegation model and administrative boundaries

## How the Test Works

This test reads `$adState.DaclEntries`, filters for `InheritedObjectType` GUIDs that are not the all-zero default value, and counts the distinct GUIDs present.

## Related Tests

- `Test-MtAdDaclInheritedObjectTypeDetails` - Provides a breakdown by inherited object type GUID
- `Test-MtAdDaclNonInheritedAceCount` - Counts ACEs that are explicitly assigned
- `Test-MtAdDaclPrivilegedAllowAceDetails` - Shows privileged allow authorizations in DACLs

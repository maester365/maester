# Test-MtAdDaclOuObjectCount

## Why This Test Matters

Organizational Units are a common delegation boundary in Active Directory. Understanding how many DACL entries apply to OU objects helps focus permission review on objects that commonly control administration and policy scoping.

- **Highlights OU permission surface area**
- **Supports delegation review** for administrative boundaries
- **Provides context** for OU-focused DACL investigations

## Security Recommendation

Review OU permissions regularly, especially where OUs host privileged users, servers, or administrative delegation models. Unexpectedly large or complex OU ACLs can indicate legacy delegation that should be validated.

## How the Test Works

This test retrieves `$adState.DaclEntries`, filters entries where `ObjectClass` equals `organizationalUnit`, and reports the count of OU DACL entries and distinct OU objects represented.

## Related Tests

- `Test-MtAdDaclDistinctObjectCount`
- `Test-MtAdDaclDenyAceCount`
- `Test-MtAdDaclDenyAceDetails`

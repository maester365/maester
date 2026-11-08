---
title: Active Directory Advanced Topics
sidebar:
  label: Active Directory
  order: 1
---

# Active Directory Permission Model

- Version: 3.0
- Methodology: Extracted from `[MaesterTest] Permission` attribute on each AD test
- Total tests: 270
- Format: `<Service>:<Kind>:<Name>`

The permission model documents the exact minimum permissions each built-in AD test requires. It does not describe human role names (e.g., Domain Admin); it describes the technical permission a test needs to retrieve its data.

## Permission Format

Every AD test declares its permissions via the `[MaesterTest]` `Permission` attribute as one or more strings in this format:

```
<Service>:<Kind>:<Name>
```

| Segment | Description | Examples |
|---|---|---|
| `Service` | Service registry name the test also lists in `Service` | `ActiveDirectory`, `Graph`, `Azure` |
| `Kind` | Kind of grant for that service | `Ldap`, `Cim`, `File`, `Remoting`, `Group` |
| `Name` | Permission as the product spells it (everything after the second colon) | `domainDNS.msDS-Behavior-Version:ReadProperty`, `SYSVOL:Read`, `Microsoft.PowerShell` |

### AND / OR semantics

- **Array elements are AND** — the identity needs every element.
- **Pipe `|` inside an element is OR** — any one alternative is enough, least privileged first.

```powershell
# Both required
Permission = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty')

# Either sufficient
Permission = 'ActiveDirectory:Ldap:domainDNS.name:ReadProperty | ActiveDirectory:Ldap:domainDNS:ReadProperty'

# (One domain attribute OR another) AND group access
Permission = ('ActiveDirectory:Ldap:domainDNS.name:ReadProperty | ActiveDirectory:Ldap:domainDNS:ReadProperty',
              'ActiveDirectory:Ldap:group:ReadProperty')
```

Use parenthesized constant lists `('a', 'b')` in the attribute, not `@('a', 'b')`.

### Examples

| Test | Permission string | What it means |
|---|---|---|
| `AD-DOM-01` | `ActiveDirectory:Ldap:domainDNS.name:ReadProperty` | Read the `name` attribute on the `domainDNS` object via LDAP |
| `AD-DACL-01` | `ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl` | Read `ntSecurityDescriptor` (with DACL) on all object classes via LDAP |
| `AD-GPO-01` | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty` | Read GPO LDAP metadata |
| `AD-GPO-01` | `ActiveDirectory:File:SYSVOL:Read` | Read GPO files from SYSVOL share |
| `AD-DNS-01` | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read` | Read DNS zone data via CIM |
| `AD-DNS-01` | `ActiveDirectory:Remoting:Microsoft.PowerShell` | Execute commands via PowerShell remoting endpoint |
| `AD-DC-02` | `ActiveDirectory:Cim:root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration:Read` | Read SMB configuration via CIM |

These are technical permission strings, not human role names. A test that requires `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty` needs the technical ability to read that specific GPO attribute; it does not require membership in a built-in administrative group.

## Querying Test Permissions

Every AD test declares its permissions via the `[MaesterTest] Permission` attribute. You can query them dynamically:

```powershell
Import-Module Maester -Force
$test = Get-MtTest -Path ./tests/ad/domain/Test.AD-DOM-01.ps1
$test.Permission  # outputs: ActiveDirectory:Ldap:domainDNS.name:ReadProperty
```

Or discover all AD test permissions in bulk:

```powershell
Get-ChildItem ./tests/ad -Recurse -Filter 'Test.AD-*.ps1' | ForEach-Object {
    $test = Get-MtTest -Path $_.FullName
    [PSCustomObject]@{
        Id = $test.Id
        Permissions = $test.Permission -join '; '
    }
}
```

The `ADPermissionValidation.Tests.ps1` unit test validates that every AD test's `Permission` attribute parses without engine errors. Run it to verify the model:

```powershell
Invoke-Pester ./powershell/tests/general/ADPermissionValidation.Tests.ps1
```

## Active Directory Permission Kinds

| Kind | Name format | Example |
|---|---|---|
| `Ldap` | `[<partition>/]<objectClass>[.<attribute>]:<right>` | `ActiveDirectory:Ldap:Configuration/*:ReadProperty` |
| `Cim` | `<namespace>:<class>:<right>` | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read` |
| `File` | `<share>:<right>` | `ActiveDirectory:File:SYSVOL:Read` |
| `Remoting` | `<endpoint>` | `ActiveDirectory:Remoting:Microsoft.PowerShell` |
| `Group` | `<group name>` | `ActiveDirectory:Group:Remote Management Users` |

For LDAP, the optional partition is `Configuration` or `Schema`; omitted means the domain. `objectClass.attribute` reads one attribute; omitting `.attribute` reads all attributes of that object class.

## Tests Requiring Elevated Privileges

A standard **authenticated user** (Domain User) can read many LDAP attributes through default object ACLs. The following collection paths have additional access or platform requirements; whether a particular identity needs elevation depends on the effective ACLs and transport permissions.

### DACL checks

| Tests | Required Permission | Why It Requires Elevation |
|---|---|---|
| AD-DACL-01, 02, 03, 05, 07, 09, 11, 14, 15, 17 | `ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl` | Reading a DACL requires READ_CONTROL access, which can be restricted by object ACLs. Do not infer effective access from a group name. DACL parsing also requires Windows. |

### DNS Tests (19 tests)

| Tests | Required Permissions | Why It Requires Elevation |
|---|---|---|
| AD-DNS-01 through AD-DNS-19 | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` | Remote CIM/WMI access and PowerShell remoting both require administrative or specific group membership. |

### DC Management Tests (3 tests)

| Tests | Required Permissions | Why It Requires Elevation |
|---|---|---|
| AD-DC-02, AD-DC-03, AD-DC-04 | `ActiveDirectory:Cim:root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` | Remote CIM access for SMB server configuration and PowerShell remoting execution require elevated access. |

### GPO checks

| Tests | Required Permission | Why It May Require Elevation |
|---|---|---|
| AD-GPO-*, AD-GPOL-*, AD-GPOREP-*, AD-GPOS-* | `ActiveDirectory:File:SYSVOL:Read` | Reading files from the `\\domain\SYSVOL` share. While Authenticated Users typically receive read access to SYSVOL, this is filesystem access separate from LDAP and may be restricted in hardened environments. Only surviving IDs in the catalog are available; merged count/detail checks no longer have separate rows. |

### KDS root-key visibility

AD-CFG-22 reads key metadata, never `msKds-RootKeyData`. Default key ACLs restrict visibility to privileged identities. Zero visible keys therefore reports Investigate unless complete read/list access was independently confirmed using `KeyInventoryReadAccessConfirmed`. Do not add a key based only on an empty search by a restricted reader.

Use `Get-MtTest -Product ad` for the current catalog and each check's declared permissions. Static test counts or membership in a named group do not establish effective read access.

## Category Summary

| Category | Tests | Required permissions |
|---|---|---|
| `cfg` | AD-CFG-02, 03, 06–24 | `ActiveDirectory:Ldap:Configuration/*:ReadProperty`; CFG-22 additionally needs confirmed inventory visibility for a zero-key failure |
| `comp` | AD-COMP-01, 03–08 | `ActiveDirectory:Ldap:computer:ReadProperty`; COMP-04 also uses the DC inventory |
| `dacl` | AD-DACL-01, 02, 03, 05, 07, 09, 11, 14, 15, 17 | `ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl` |
| `dc` | AD-DC-01 through AD-DC-08 | `ActiveDirectory:Ldap:nTDSDSA:ReadProperty`; AD-DC-02 through AD-DC-04 also need `ActiveDirectory:Cim:root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration:Read` and `ActiveDirectory:Remoting:Microsoft.PowerShell` |
| `dcd` | AD-DCD-01 through AD-DCD-04 | `ActiveDirectory:Ldap:nTDSDSA:ReadProperty` |
| `dcomp` | AD-DCOMP-01, 03, 04, 06, 07, 08 | Computer and DC inventory permissions; DCOMP-01/03 also read sMSA, gMSA and dMSA delegation metadata |
| `dfsr` | AD-DFSR-01 | `ActiveDirectory:Ldap:domainDNS.distinguishedName:ReadProperty` |
| `dns` | AD-DNS-01 through AD-DNS-19 | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` |
| `dom` | AD-DOM-01 through AD-DOM-08 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `doms` | AD-DOMS-01 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `feat` | AD-FEAT-01 | `ActiveDirectory:Ldap:msDS-OptionalFeature:ReadProperty` |
| `fgpp` | AD-FGPP-01 through AD-FGPP-04 | `ActiveDirectory:Ldap:msDS-PasswordSettings:ReadProperty` |
| `for` | AD-FOR-01 through AD-FOR-04 | `ActiveDirectory:Ldap:crossRef:ReadProperty` |
| `fors` | AD-FORS-01 through AD-FORS-04 | `ActiveDirectory:Ldap:crossRef:ReadProperty` |
| `gchg` | AD-GCHG-01 | `ActiveDirectory:Ldap:group:ReadProperty` |
| `gmc` | AD-GMC-01, 02, 04, 06, 08, 10 | `ActiveDirectory:Ldap:group:ReadProperty`; membership checks also need `ActiveDirectory:Ldap:group.member:ReadProperty` |
| `gpo` | AD-GPO-01, 02, 04 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `gpol` | AD-GPOL-01–05 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `gporep` | AD-GPOREP-01, 03, 05, 06, 07, 09, 10, 12, 14, 15, 17 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read`; ACL-dependent checks need readable security descriptors |
| `gpos` | AD-GPOS-01 through AD-GPOS-09 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `grp` | AD-GRP-01–06, 08 | `ActiveDirectory:Ldap:group:ReadProperty` |
| `krbtgt` | AD-KRBTGT-01 through AD-KRBTGT-03 | `ActiveDirectory:Ldap:user:ReadProperty` |
| `msa` | AD-MSA-01 | `ActiveDirectory:Ldap:msDS-ManagedServiceAccount:ReadProperty`, `ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount:ReadProperty`, `ActiveDirectory:Ldap:msDS-DelegatedManagedServiceAccount:ReadProperty` |
| `ou` | AD-OU-01 through AD-OU-05 | `ActiveDirectory:Ldap:organizationalUnit:ReadProperty` |
| `print` | AD-PRINT-01 | `ActiveDirectory:Ldap:printQueue:ReadProperty` |
| `pwdpol` | AD-PWDPOL-01 through AD-PWDPOL-07 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `repl` | AD-REPL-01 through AD-REPL-02 | `ActiveDirectory:Ldap:nTDSConnection:ReadProperty` |
| `rootdse` | AD-ROOTDSE-01, 03 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `sch` | AD-SCH-01, 03, 05 | `ActiveDirectory:Ldap:Schema/*:ReadProperty`; SCH-05 distinguishes Windows LAPS schema from legacy LAPS |
| `site` | AD-SITE-01 through AD-SITE-05 | `ActiveDirectory:Ldap:site:ReadProperty` |
| `spn` | AD-SPN-01, 03, 05, 06, 07, 09, 11, 12 | Computer/user permissions; SPN-12 also reads domain SID, groups and group membership |
| `sub` | AD-SUB-01 through AD-SUB-11 | `ActiveDirectory:Ldap:subnet:ReadProperty` |
| `trust` | AD-TRUST-01, 02, 03, 06 | `ActiveDirectory:Ldap:trustedDomain:ReadProperty`; TRUST-06 cannot infer validation age from LDAP modification dates |
| `user` | AD-USER-01–13, 15–29 | `ActiveDirectory:Ldap:user:ReadProperty`; USER-14 was consolidated into SPN-06 |

## Known Misleading Outcomes

The following behaviors can hide incomplete access. They are documented here so operators do not misinterpret empty or partial results as proof of a clean configuration.

### DACL tests (AD-DACL-*)

Merged DACL checks reject missing or empty collected entries rather than reporting a clean inventory. A nonempty response still does not prove that every object's DACL was readable. Confirm read access to the intended scope; DACL parsing requires Windows.

### GPO tests (AD-GPO-*, AD-GPOL-*, AD-GPOREP-*, AD-GPOS-*)

`Get-MtADGpoState` uses `$null` for failed metadata or report collection, distinct from an empty inventory. The merged version and exposed-password checks reject incomplete reports or scans, including unreadable/malformed XML. GPOREP-10 skips off Windows because its permission parsing is Windows-only. An LDAP probe alone does not prove SYSVOL access or complete collection.

### DNS tests (AD-DNS-*)

If DNS management collection fails, the category is unavailable: scoped calls return null properties, and legacy unscoped calls may omit DNS keys. Do not interpret missing DNS data as an empty, healthy inventory.

### Configuration tests (AD-CFG-*)

Configuration searches tolerate absent optional containers, but propagate genuine query failures so the category is unavailable. The Directory Service retrieval flag distinguishes an unreadable/missing object from unset attributes. LDAP ACL filtering can still hide objects without a query error, particularly KDS keys; zero visible results alone cannot establish absence.

### Transport and cache

WinRM HTTPS-to-HTTP Negotiate fallback (commit `ca74fc79`) means a successful management result may have used HTTP; it does not prove the HTTPS listener or certificate was validated. `Get-MtADGpoState` caches by resolved domain and may reuse state across DCs. The target-scoped `Get-MtADDomainState` cache includes resolved target identity. Do not assume all scoped collections share unscoped data.

**This documents current behavior, not a future enforcement model.** Tests do not consistently emit `LimitedPermissions` or `NotAuthorized` when access is insufficient. A pass, skip, empty collection, or null result must be interpreted with the specific test's known ambiguity in view.

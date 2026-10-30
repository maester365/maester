---
sidebar_label: Active Directory
sidebar_position: 1
title: Active Directory Advanced Topics
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

A standard **authenticated user** (Domain User) can read most LDAP attributes on most objects via the default security descriptor. The following tests require privileges **beyond** what a standard Domain User holds by default.

### DACL Tests (18 tests)

| Tests | Required Permission | Why It Requires Elevation |
|---|---|---|
| AD-DACL-01 through AD-DACL-18 | `ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl` | Reading the DACL portion of `ntSecurityDescriptor` is restricted. Standard users can read the owner and group, but not the full DACL. |

### DNS Tests (19 tests)

| Tests | Required Permissions | Why It Requires Elevation |
|---|---|---|
| AD-DNS-01 through AD-DNS-19 | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` | Remote CIM/WMI access and PowerShell remoting both require administrative or specific group membership. |

### DC Management Tests (3 tests)

| Tests | Required Permissions | Why It Requires Elevation |
|---|---|---|
| AD-DC-02, AD-DC-03, AD-DC-04 | `ActiveDirectory:Cim:root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` | Remote CIM access for SMB server configuration and PowerShell remoting execution require elevated access. |

### GPO Tests (40 tests)

| Tests | Required Permission | Why It May Require Elevation |
|---|---|---|
| AD-GPO-01 through AD-GPO-05, AD-GPOL-01 through AD-GPOL-06, AD-GPOREP-01 through AD-GPOREP-20, AD-GPOS-01 through AD-GPOS-09 | `ActiveDirectory:File:SYSVOL:Read` | Reading files from the `\\domain\SYSVOL` share. While Authenticated Users typically receive read access to SYSVOL, this is filesystem access separate from LDAP and may be restricted in hardened environments. |

**Summary:** 80 of 270 AD tests (30%) require privileges beyond a standard authenticated user. The remaining 190 tests can run with standard Domain User LDAP read access.

## Category Summary

| Category | Tests | Required permissions |
|---|---|---|
| `cfg` | AD-CFG-01 through AD-CFG-24 | `ActiveDirectory:Ldap:Configuration/*:ReadProperty` |
| `comp` | AD-COMP-01 through AD-COMP-10 | `ActiveDirectory:Ldap:computer:ReadProperty` |
| `dacl` | AD-DACL-01 through AD-DACL-18 | `ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl` |
| `dc` | AD-DC-01 through AD-DC-08 | `ActiveDirectory:Ldap:nTDSDSA:ReadProperty`; AD-DC-02 through AD-DC-04 also need `ActiveDirectory:Cim:root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration:Read` and `ActiveDirectory:Remoting:Microsoft.PowerShell` |
| `dcd` | AD-DCD-01 through AD-DCD-04 | `ActiveDirectory:Ldap:nTDSDSA:ReadProperty` |
| `dcomp` | AD-DCOMP-01 through AD-DCOMP-09 | `ActiveDirectory:Ldap:computer:ReadProperty` |
| `dfsr` | AD-DFSR-01 | `ActiveDirectory:Ldap:domainDNS.distinguishedName:ReadProperty` |
| `dns` | AD-DNS-01 through AD-DNS-19 | `ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read`, `ActiveDirectory:Remoting:Microsoft.PowerShell` |
| `dom` | AD-DOM-01 through AD-DOM-08 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `doms` | AD-DOMS-01 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `feat` | AD-FEAT-01 through AD-FEAT-02 | `ActiveDirectory:Ldap:msDS-OptionalFeature:ReadProperty` |
| `fgpp` | AD-FGPP-01 through AD-FGPP-04 | `ActiveDirectory:Ldap:msDS-PasswordSettings:ReadProperty` |
| `for` | AD-FOR-01 through AD-FOR-04 | `ActiveDirectory:Ldap:crossRef:ReadProperty` |
| `fors` | AD-FORS-01 through AD-FORS-04 | `ActiveDirectory:Ldap:crossRef:ReadProperty` |
| `gchg` | AD-GCHG-01 | `ActiveDirectory:Ldap:group:ReadProperty` |
| `gmc` | AD-GMC-01 through AD-GMC-11 | `ActiveDirectory:Ldap:group:ReadProperty`; GMC-01 also needs `ActiveDirectory:Ldap:group.member:ReadProperty` |
| `gpo` | AD-GPO-01 through AD-GPO-05 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `gpol` | AD-GPOL-01 through AD-GPOL-06 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `gporep` | AD-GPOREP-01 through AD-GPOREP-20 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `gpos` | AD-GPOS-01 through AD-GPOS-09 | `ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty`, `ActiveDirectory:File:SYSVOL:Read` |
| `grp` | AD-GRP-01 through AD-GRP-10 | `ActiveDirectory:Ldap:group:ReadProperty` |
| `krbtgt` | AD-KRBTGT-01 through AD-KRBTGT-03 | `ActiveDirectory:Ldap:user:ReadProperty` |
| `msa` | AD-MSA-01 | `ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount:ReadProperty` |
| `ou` | AD-OU-01 through AD-OU-05 | `ActiveDirectory:Ldap:organizationalUnit:ReadProperty` |
| `print` | AD-PRINT-01 | `ActiveDirectory:Ldap:printQueue:ReadProperty` |
| `pwdpol` | AD-PWDPOL-01 through AD-PWDPOL-07 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `repl` | AD-REPL-01 through AD-REPL-02 | `ActiveDirectory:Ldap:nTDSConnection:ReadProperty` |
| `rootdse` | AD-ROOTDSE-01 through AD-ROOTDSE-03 | `ActiveDirectory:Ldap:domainDNS:ReadProperty` |
| `sch` | AD-SCH-01 through AD-SCH-05 | `ActiveDirectory:Ldap:attributeSchema:ReadProperty` |
| `site` | AD-SITE-01 through AD-SITE-05 | `ActiveDirectory:Ldap:site:ReadProperty` |
| `spn` | AD-SPN-01 through AD-SPN-13 | `ActiveDirectory:Ldap:computer:ReadProperty`, `ActiveDirectory:Ldap:user:ReadProperty` |
| `sub` | AD-SUB-01 through AD-SUB-11 | `ActiveDirectory:Ldap:subnet:ReadProperty` |
| `trust` | AD-TRUST-01 through AD-TRUST-07 | `ActiveDirectory:Ldap:trustedDomain:ReadProperty` |
| `user` | AD-USER-01 through AD-USER-29 | `ActiveDirectory:Ldap:user:ReadProperty` |

## Known Misleading Outcomes

The following behaviors can hide incomplete access. They are documented here so operators do not misinterpret empty or partial results as proof of a clean configuration.

### DACL tests (AD-DACL-*)

`Get-MtLdapDacl` delegates to `Invoke-MtLdapSearch` and returns an empty array when no entries match. An empty result is indistinguishable from insufficient access. Tests set `$testResult = $true` even when the array is empty, so a pass does not prove the DACL was fully read.

### GPO tests (AD-GPO-*, AD-GPOL-*, AD-GPOREP-*, AD-GPOS-*)

`Get-MtADGpoState` can return a non-null state with an empty GPO array. A non-null check therefore does not establish that GPO data was retrieved. GPO reads also depend on SMB/SYSVOL file access; an LDAP probe alone does not prove policy files were read.

### DNS tests (AD-DNS-*)

If `Invoke-MtADManagementCommand` fails, the DNS category collector throws. `Get-MtADDomainState` catches the failure and leaves DNS arrays empty. The helper then skips with `NotConnectedActiveDirectoryDNS`, which does not distinguish "server has no data" from "query could not retrieve data."

### Configuration tests (AD-CFG-*)

`Get-MtLdapConfigurationContainer` catches individual query errors. The state object survives with empty arrays or null properties even when subqueries did not return data.

### Transport and cache

WinRM HTTPS-to-HTTP Negotiate fallback (commit `ca74fc79`) means a successful management result may have used HTTP; it does not prove the HTTPS listener or certificate was validated. `Get-MtADGpoState` caches by resolved domain and may reuse state across DCs. The target-scoped `Get-MtADDomainState` cache includes resolved target identity. Do not assume all scoped collections share unscoped data.

**This documents current behavior, not a future enforcement model.** Tests do not consistently emit `LimitedPermissions` or `NotAuthorized` when access is insufficient. A pass, skip, empty collection, or null result must be interpreted with the specific test's known ambiguity in view.

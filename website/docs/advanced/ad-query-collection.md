---
title: Modular Active Directory queries
---

# Modular Active Directory queries

Maester provides an opt-in LDAP query API for custom tests and collectors. It adds
`New-MtADQuery`, `Invoke-MtADQuery` and `ConvertTo-MtLdapFilterValue`; it does not
replace or change the existing Active Directory collectors. Connect first with
`Connect-Maester -Service ActiveDirectory` so Maester can validate the target.

These three exported commands are public API for custom tests and collectors. Their
documented query parameters and result shapes form the compatibility contract;
existing internal collector helpers are not promoted to public commands.

## Define and run a query

`New-MtADQuery` creates a reusable query definition without contacting a domain
controller. Its small starter selections are `User`, `Computer`, `Group`,
`OrganizationalUnit` and `Gpo`. They are intentionally not the richer projections
or legacy output shapes used by existing collectors. You can replace a starter's
attribute selection, or describe a custom query with explicit attributes:

```powershell
$query = New-MtADQuery -Name User -Attributes name,sAMAccountName,userAccountControl
$users = Invoke-MtADQuery -Query $query

$custom = @{
    SearchBase = 'OU=Service Accounts,DC=example,DC=com'
    Scope = 'OneLevel'
    Filter = '(objectClass=user)'
    Attributes = @('name', 'sAMAccountName')
}
$accounts = Invoke-MtADQuery -Query $custom
```

Queries can also be passed through the pipeline or specified directly:

```powershell
@($query, (New-MtADQuery -Name Group -Attributes name,member)) |
    Invoke-MtADQuery -AsResult

$computers = Invoke-MtADQuery -Name Computer
$schema = Invoke-MtADQuery -NamingContext Schema `
    -Filter '(objectClass=attributeSchema)' -Attributes name,lDAPDisplayName
```

`Invoke-MtADQuery` accepts a query object, dictionary or `PSCustomObject`. A query
uses the connected server's `Default` naming context unless another context is
selected; `Configuration` and `Schema` are also available. Alternatively, supply
an explicit distinguished name with `SearchBase`. These options cannot be combined.
Use `SearchBase '' -Scope Base` to query RootDSE. The default scope is `Subtree`.
The default filter is `(objectClass=*)`; a named starter supplies its own filter.

By default the command emits entries. With `-AsResult`, it emits an envelope with
`Entries`, the normalized `Request`, and UTC `CollectedAt` metadata. Each entry has
a scalar `DistinguishedName` and an `Attributes` dictionary. Attribute names are
lowercase and values are always arrays, including single-valued attributes:

```powershell
$users[0].DistinguishedName
$users[0].Attributes['samaccountname'][0]
```

The distinguished name is always available on the entry, even when it was not
requested as an attribute. Absent attributes are omitted;
their absence cannot tell you whether an attribute is unset or unreadable. Known
GUID attributes are returned as `[guid]` values and known SID attributes as strings.
Standard text attributes (including the starter selections, `member`, `memberOf`,
`description`, `servicePrincipalName` and `lDAPDisplayName`), and known date, integer,
boolean and interval attributes are decoded by name. Invalid UTF-8 for a known text
attribute throws. FILETIME values of `0` and `Int64.MaxValue` remain integers so their
unset/never meanings are not lost. Other attributes received as bytes remain byte
arrays, **even if they contain text**. This API does not read the schema to infer their
types. To decode a custom text attribute whose syntax you know, use:

```powershell
[Text.UTF8Encoding]::new($false, $true).GetString($entry.Attributes['customattribute'][0])
```

Security descriptors remain byte arrays on all operating systems and are not parsed.
No live credentials or LDAP
connection objects are included in results.

## Filters, completeness and caching

Filters are raw LDAP filter syntax. Escape interpolated assertion values with
`ConvertTo-MtLdapFilterValue`, which supports strings, byte arrays and GUIDs (using
AD GUID byte order). It escapes filter assertion values only: it does not escape DNs,
attribute names or an entire filter. Do not build filters from untrusted raw input.
Pass binary values with `-Value $bytes`, not `$bytes | ConvertTo-MtLdapFilterValue`,
because PowerShell enumerates byte arrays in the pipeline.
The query validator accepts explicit LDAP display names
only; wildcards, OIDs, attribute options and known password or recovery-secret
attributes are rejected. This denylist helps prevent accidental secret collection,
but is not an authorization boundary.

Results are collected completely, including LDAP pages and ranged attributes,
before they are returned or cached. A successful empty result is cached. If a query,
page or range continuation fails, the command throws and returns no partial result.
The query's domain-scope control confines the search to its naming context; this
does not make a query across one context a complete forest inventory. The validated
target is pinned for the query rather than rediscovered through DNS.

Successful results are cached on first read for the Maester session. This is a
per-query cache, not an atomic directory snapshot: different queries can observe
directory changes made at different times. `Clear-MtADCache` with no parameters
clears this cache; per-run session reset and AD disconnect also clear it. Legacy
category-scoped cache resets do not clear these query results. Reconnection or a
change in connection state, credential reference or target identity invalidates the
new query cache. There is no cache-bypass switch.

The API holds complete results in memory and returns independent copies on cache
hits. Copying large results consumes CPU as well as memory, even without another
LDAP request. Request only the
attributes and scope needed.

## Opt-in migration for custom collectors

The new commands are exported and available to custom tests. For example, an
external collector can opt in and adapt the new result contract to its own shape:

```powershell
function Get-MyUserInventory {
    $entries = Invoke-MtADQuery -Query (
        New-MtADQuery -Name User -Attributes name,sAMAccountName,userAccountControl)

    foreach ($entry in $entries) {
        $uac = $entry.Attributes['useraccountcontrol']
        [pscustomobject]@{
            DistinguishedName = $entry.DistinguishedName
            SamAccountName = if ($entry.Attributes.Contains('samaccountname')) {
                $entry.Attributes['samaccountname'][0]
            } else { $null }
            Enabled = if ($null -ne $uac -and $uac.Count -gt 0 -and $null -ne $uac[0]) {
                -not ([int]$uac[0] -band 2)
            } else { $null }
        }
    }
}
```

Existing `Get-MtLdap` helpers, `ADDomainState`, `ADGpoState`, `ADDacls` and the
legacy query catalog are not rewired to this API. Their richer projections, gates,
and contracts (including distinctions between null and empty results) remain in
place. This API does not add automatic affected-object reporting or persistent
cache storage.

Any future internal migration should preserve the original attributes, filters and
security-descriptor controls, as well as range and relationship semantics, category
dependencies, and failure/skip behavior. Compare old and new results against fixtures
on Windows and Linux. The new query cache currently supports full reset only, so a
coordinated aggregate invalidation strategy is needed before legacy collectors can
share it. Do not bypass the session cache as a migration workaround.

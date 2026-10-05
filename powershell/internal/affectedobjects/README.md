# Affected objects

Builds a consolidated inventory of all objects ("affected objects") involved in a Maester test run —
Microsoft Entra ID objects, tenant-level configuration surfaces, Microsoft Graph resources,
and external systems such as GitHub. The result is attached to the Maester results object as
the top-level `AffectedObjects` property, written to `<name>-affected-objects.json` (and
`<name>-affected-objects.csv` with `-ExportCsv`), and rendered on the **Affected objects** page of the HTML report.

## Opting in

Collection is off by default: `Invoke-Maester -IncludeAffectedObjects` turns it on and the html
report then offers the **Affected objects** page. The switch sets
`$__MtSession.IncludeAffectedObjects`, which gates the per-test `RelatedObjects` capture in
`Add-MtTestResultDetail`, and is passed to `ConvertTo-MtMaesterResult`, which gates the merge
and the `AffectedObjects` property. A report generated without it carries none of this data (no
`RelatedObjects` on the test results, no affected objects entries in `OutputFiles`) and the report's
sidebar does not offer the page.

`-RedactUserIdentity` needs the inventory to know which values belong to which user, so it
collects one even when `-IncludeAffectedObjects` was not passed. In that case `Invoke-Maester`
removes the `AffectedObjects` property again once the replacement map has been built, so the
report does not grow and the page does not appear unasked.

`Get-MtHtmlReport` embeds a slim copy: per record only `System`, `Type`, `Id`, `DisplayName`,
`PortalLink`, `Tests` and a `Referenced` flag (true when a check pointed at the object rather than
only the request cache), and no `RelatedObjects` on the tests. The JSON output and the objects
files keep the full records.

The page also needs a report template built from current `/report/src`. If
`<name>-affected-objects.json` was written but the sidebar has no Affected objects entry, the check-in
artifact `powershell/assets/ReportTemplate.html` is stale — see the stale template
troubleshooting section in [report/README.md](../../../report/README.md).

## Record schema

Every source normalizes into the same record shape so results can be merged and deduplicated:

| Field               | Description                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `System`            | Where the object lives: `EntraID`, `MicrosoftGraph`, `DefenderXDR`, `ExchangeOnline`, `GitHub`, ...               |
| `AnchorKind`        | How the object is identified — see [Anchor kinds](#anchor-kinds)                                                  |
| `Type`              | Canonical object type (`ConditionalAccessPolicy`, `User`, `Group`, `ServicePrincipal`, Graph resource path, ...) |
| `Id`                | Object id (GUID), resource key (`Fido2`), or external identity (`org/repo`); `$null` for singletons/collections  |
| `DisplayName`       | Human-readable name when the source provides one                                                                 |
| `UserPrincipalName` | UPN of a user object when the source provides one; used by PII redaction                                          |
| `PortalLink`        | Admin-portal deep link when a template exists for the type                                                       |
| `Tests`             | Test ids (`MT.xxxx`, ...) that referenced the object (aggregated)                                                 |
| `Sources`           | Which of the three detection sources found it (aggregated)                                                       |

## Anchor kinds

The classification answers "what kind of identifier anchors this object?":

- **Instance** — a single addressable object with its own id (a CA policy, a user, a group,
  a service principal, a transport rule). Strongest anchor; usually has a portal deep link.
- **Singleton** — a tenant-level configuration resource with no id; the Graph URI itself is
  the identity (`policies/authorizationPolicy`, `settings`). All EIDSCA checks anchor here.
- **Surface** — a portal settings page that a check points to without addressing a specific
  object (e.g. the Authentication Methods blade).
- **Collection** — a Graph collection read (`users`, `servicePrincipals`); records that the
  run touched the data set, not a specific member.
- **External** — an object outside Microsoft Graph, identified by its API path
  (GitHub organization/repository, Azure DevOps organization).
- **Unknown** — a structured object without an id (an instance type passed with no `id`, or
  an object with neither type nor id). It is not addressable, so it gets no portal link.

## The three detection sources

Detection runs in `ConvertTo-MtMaesterResult` (wrapped in try/catch — inventory problems
never fail a test run) via `Get-MtAffectedObject`, which merges three independent sources:

### 1. Structured capture — `RelatedObjects` (strongest, per-test attribution)

When a test calls `Add-MtTestResultDetail -GraphObjects ...`, the objects are converted by
`ConvertTo-MtAffectedObjectRecord` into records **before** they are flattened into result markdown
(previously the ids were lost at that point). Type resolution, in order:

1. Explicit `-GraphObjectType` parameter, mapped to a canonical type name
   (`ConditionalAccess` → `ConditionalAccessPolicy`, `Users`/`UserRole` → `User`,
   `Groups` → `Group`, `Devices` → `Device`) so records dedupe against source 2.
2. `@odata.type` sniffing per object (`#microsoft.graph.user` → `User`, etc.), using the
   shared mapping in `Get-MtPortalLinkTemplate`, plus object-only mappings for
   `servicePrincipal`, `directoryRole` and `conditionalAccessPolicy`.
3. Other types are still captured: the raw `@odata.type` becomes the `Type`, and the record
   is an `Instance` if the object has an id. Unless the type is added to the catalog, the
   type filter then drops it with a warning (see below).

Portal deep links come from the same shared template table (`Get-MtPortalLinkTemplate`),
which is environment-aware via `$__MtSession.AdminPortalUrl` (Global/USGov/China clouds).
The records are stored per test in `$__MtSession.TestResultDetail[<test>].RelatedObjects`
and flow into the report JSON under `Tests[n].ResultDetail.RelatedObjects`.

### 2. Markdown deep-link parsing (covers ad-hoc links and old reports)

`Get-MtAffectedObjectFromMarkdown` enumerates the links in each test's rendered result
markdown (`ResultDetail.TestResult`) once, then tests every URL it finds against a regex table
of the known admin-portal deep-link patterns used across the shipped checks — the URL blade
pattern acts as a type system:

| URL pattern (fragment)                                        | Type                           |
| ------------------------------------------------------------- | ------------------------------ |
| `Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{guid}` | ConditionalAccessPolicy        |
| `ManagedAppMenuBlade/~/*/objectId/{guid}/appId/{guid}`        | ServicePrincipal               |
| `ApplicationMenuBlade/~/*/appId/{guid}`                       | AppRegistration                |
| `UserProfileMenuBlade/~/*/userId/{guid}`                      | User                           |
| `GroupDetailsMenuBlade/~/*/groupId/{guid}`                    | Group                          |
| `DeviceDetailsMenuBlade/~/*/objectId/{guid}`                  | Device                         |
| `Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/{guid}`      | AccessPackageCatalog           |
| `EntitlementMenuBlade/~/overview/entitlementId/{guid}`        | AccessPackage                  |
| `Microsoft_Azure_PIMCommon/AlertDetail/.../alertId/{id}`      | PimAlert                       |
| `RecommendationDetails.ReactView/recommendationId/{id}`       | EntraRecommendation            |
| `security.microsoft.com/machines/v2/{deviceId}`               | Device (DefenderXDR)           |
| `admin.exchange.microsoft.com .../ruleDetails/{guid}`         | TransportRule (ExchangeOnline) |
| `.../individualsharingdetails/{id}`                           | SharingPolicy (ExchangeOnline) |

The first pattern that matches a URL owns it, so ordering resolves overlaps (a service
principal URL also satisfies the less specific app registration pattern). The matched URL
becomes the record's `PortalLink`, and when it sits inside a markdown link `[name](url)` the
display name is recovered from the link that owns it. Only `https://` URLs are considered:
display names are not escaped in result markdown, so a crafted name could otherwise smuggle a
`javascript:` URL into the Affected objects page.
This source catches the ~55 checks that build `$portalLink` strings by hand (XSPM, CISA
Exchange, PIM, entitlement management, ...) without going through `Get-GraphObjectMarkdown`,
and it works post-hoc on any previously collected report JSON.

### 3. Session request caches (run-level completeness)

`Get-MtAffectedObjectFromCache` walks the per-run request caches, whose keys are the
request URLs — a free record of every resource the run actually read:

- **`$__MtSession.GraphCache`** — URI path parsing per key:
  - a keyed read of a directory collection (`users`, `groups`, `devices`,
    `servicePrincipals`, `directoryRoles`) → **Instance** under the canonical EntraID type,
    whatever sub-resource follows: `users/{id}/authentication/methods` is the user, not a
    separate object. The key may be a GUID **or a UPN** — `users/alice@contoso.com` must
    resolve to `EntraID | User | alice@contoso.com`, because a UPN left inside `Type` is
    never reached by the report's PII redaction (which matches on `Type -eq 'User'`).
    `applications` is deliberately excluded: the cache keys it by object id while the portal
    links parsed from markdown carry the app id, so the two would not merge anyway.
  - any other GUID segment or an OData key segment
    (`authenticationMethodConfigurations('Fido2')`, or an alternate key such as
    `applications(appId='{guid}')`) → **Instance**. The **first** key in the
    path wins, so `policies/{id}/assignments/{id}` anchors on the policy rather than the
    child; remaining segments become `Type`.
  - no key, but under a known config prefix (`policies`, `settings`, `organization`,
    `admin`, `reports`, `networkAccess`, ...) → **Singleton**
  - otherwise → **Collection**
  - query strings are stripped; POST bodies carry no resource identity, and action endpoints
    (`$batch`, `runHuntingQuery`, `getMemberObjects`, ...) are verbs rather than resources
    and are skipped
- **`$__MtSession.GitHubCache`** — keys are `{ApiVersion}|{AbsoluteUri}`;
  `/orgs/{org}` → GitHubOrganization, `/repos/{owner}/{repo}` → GitHubRepository
  (both **External**).

Cache records have no per-test attribution (the caches are shared across the run), so they
appear with an empty `Tests` list — shown as "run-level" in the report.

Records that address a directory object are normalized onto `System` `EntraID` and the
canonical type, so a check that both reads `groups/{id}` and renders a portal link for it
produces one object carrying both `Markdown` and `GraphCache` in `Sources`. Everything else
keeps `System` `MicrosoftGraph` and the Graph resource path as `Type`, answering "what data
did the run read?" rather than "which object did a check flag?".

## Merge and deduplication

`Get-MtAffectedObject` groups all records on `System|Type|Id`. A record without an id falls
back to its UPN, then its display name, so distinct users passed without an id stay separate
objects (and are each redacted) instead of merging into one:

- The best record per object wins by source rank: structured `GraphObjects` (0) beats
  `Markdown` (1) beats cache (2) — so a portal link or display name from the structured
  path is preferred.
- `DisplayName`/`PortalLink` fall back to the first non-empty value across the group.
- `Tests` and `Sources` are unioned across all records of the object.

This is why canonical type names matter: the same CA policy found via `-GraphObjects` and
via a markdown deep link must produce the same `Type` (`ConditionalAccessPolicy`) to
collapse into a single object with both tests attributed.

## Object type catalog (what counts as an affected object)

After the merge, `Select-MtAffectedObjectByType` filters the inventory against the catalog in
`Get-MtAffectedObjectTypeDefinition`:

| Bucket          | Behaviour                                                                                                                                    |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `KnownTypes`    | Systems whose `Type` values are curated and enumerable (`EntraID`, `DefenderXDR`, `ExchangeOnline`, `GitHub`). Listed types are inventoried. |
| `ExcludedTypes` | Recognised types that are deliberately not affected objects. Dropped silently.                                                                         |
| Everything else | Systems absent from `KnownTypes` (`MicrosoftGraph`) pass through unchanged — their `Type` is a Graph resource path and cannot be enumerated. |

Currently inventoried: `EntraID` — AccessPackage, AccessPackageCatalog, AppRegistration,
AuthenticationMethod, AuthorizationPolicy, ConditionalAccessPolicy, ConsentPolicy, Device,
DirectoryRole, Domains, Group, ServicePrincipal, User; `DefenderXDR` — Device;
`ExchangeOnline` — SharingPolicy, TransportRule; `GitHub` — GitHubOrganization,
GitHubRepository, GitHubResource.

Excluded: `EntraID` — `EntraRecommendation`, `PimAlert`. Both describe a condition of the
tenant (a recommendation, an alert), not an addressable object, so they are findings that
belong in the test result, not rows in an object inventory.

A record of a curated system whose type is **not** in either list is dropped and reported in
a single `Write-Warning` summary (`System/Type (count)`), so a newly linked object type shows
up as an explicit maintenance item instead of silently reaching the report. Add it to
`KnownTypes` to inventory it, or to `ExcludedTypes` if it is not an affected object.

`ConvertTo-MtAffectedObjectRecord` also resolves type aliases before the record is built:
`IdentityProtection` objects are the users at risk, so they are recorded as `User`
(`Instance` with a user profile deep link) rather than as the Identity Protection blade.

## Extending detection

- **New portal deep-link pattern** → add a row to the regex table in
  `Get-MtAffectedObjectFromMarkdown` (keep more specific patterns first; the first capture
  group must be the id).
- **New `-GraphObjectType`** → add the ValidateSet entry in `Add-MtTestResultDetail`,
  the link template + instance flag in `Get-MtPortalLinkTemplate`,
  and (if the markdown parser has a matching pattern) the canonical name mapping in
  `ConvertTo-MtAffectedObjectRecord`.
- **New external system** → extend the cache walker in `Get-MtAffectedObjectFromCache`
  (or add a new source function and merge it in `Get-MtAffectedObject`).
- **New object type reaching the inventory** → add it to `Get-MtAffectedObjectTypeDefinition`
  (`KnownTypes` to keep it, `ExcludedTypes` to drop it); until then it is filtered out and
  named in the dropped-types warning.

## Redacting user identities

`Get-MtUserIdentityReplacementMap` turns the inventory's `User` objects into a map of
display name / UPN / object id → `UniqueId`. `Invoke-Maester` also passes `-IncludeSessionCache`,
which adds the UPN and object id (not the display name) of every user object in the cached Graph
responses, including users only read as part of a list, such as the member users MT.1033 names in
its test titles. The signed-in account (`Account`, `MgContext.Account`) is always mapped, since
every report carries it. `ConvertTo-MtRedactedReportContent` applies that map to rendered
report content, matching case-insensitively (UPNs and object ids are case-insensitive) and on word boundaries so a short display name cannot rewrite the middle
of an unrelated word (a service account named `Test` must not turn `TestResult` into a token).
With `-JsonEncoded` only json string values are rewritten, never property names, so a user
named like a property (`Severity`) cannot leave the report unparseable. Object ids and UPNs are
found by their shape and looked up in a dictionary, and only the remaining values (display names
and escaped forms) go into a regex alternation, so a tenant with tens of thousands of cached users
does not slow redaction down. `Get-MtAffectedObjectUniqueId` is the
single place the id is derived, so the html report, the json/markdown exports and the objects
files all use the same token. It lower-cases the `System|Type|Id` identity before hashing,
because the grouping that feeds it is case-insensitive while URL casing is not stable across
runs.

Redaction is pseudonymization, not anonymization: `UniqueId` is an unsalted SHA-256 over the
object identity with no tenant component, so a token is reversible by anyone holding a list of
candidate ids or UPNs, and the same user yields the same token in every tenant's report.

Redaction against json must pass `-JsonEncoded`: `ConvertTo-Json` escapes quotes, backslashes
and (on Windows PowerShell) non-ASCII characters, so the raw display name alone would not match
the serialized text. Display names shorter than four characters are skipped because a
substring replacement of them would corrupt unrelated words.

`Invoke-Maester -RedactUserIdentity` selects the scope: `None`, `HtmlOnly` (html report only) or
`AllOutputs` (every output).

## Offline validation

Offline validation without a tenant: mock `$__MtSession` (AdminPortalUrl + caches), stub
`Write-MtProgress`/`Get-MtPesterTagValue`/`Get-MtTestResultTemplate`/`Get-MtSkippedReason`,
dot-source the functions above, and assert on the produced records.

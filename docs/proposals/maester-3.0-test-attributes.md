# Design: test attributes in Maester 3.0

Status: accepted for implementation, 2026-10-11. This document replaces the `Category`, `Preview` and tag rules of
the [3.0 design](./maester-3.0-design.md) (sections 3.2, 4 and 7.1). Everything else in that design stands.

## 1. Summary

In 2.x and in the first 3.0 previews a test was described by one free-text `Category` and a list of free-form
tags. Between them they carried eight different ideas: suite, product, topic, benchmark control, benchmark
version, licence, severity and theme. Neither could drive a clean report filter, and a new idea meant a new tag
convention.

This design gives each idea its own typed attribute, drawn from a closed list where a list makes sense, and
stops using tags for Maester's own taxonomy. A test answers six questions:

| Question | Attributes |
| --- | --- |
| Which test is this? | `Id`, `Title` |
| What is it about? | `Product`, `RelatedProduct`, `Feature`, `Area`, `ResourceType` |
| What do I fix first? | `Severity`, `UserImpact`, `ImplementationCost` |
| What does it map to? | `Mitre`, `Control` |
| Can it run here? | `Service`, `License`, `Permission`, `TenantType`, `Cloud`, `Platform` |
| Is it current? | `Lifecycle`, `ReplacedBy` |

`Category` and `Preview` are removed. `Tag` stays as a free label for the owner of a test folder and no longer
carries taxonomy. The rules for choosing each value are in the
[attribute rubric](../../website/docs/writing-tests/attribute-rubric.md); this document specifies the mechanics.

## 2. The attribute

```powershell
[MaesterTest(
    Id                 = 'MT.1012',
    Title              = 'MFA is required for risky sign-ins',

    Product            = 'entra',
    Feature            = 'conditional-access',
    Area               = 'authentication',
    ResourceType       = 'Tenant',

    Severity           = 'High',
    UserImpact         = 'Low',
    ImplementationCost = 'Low',

    Mitre              = ('T1078.004', 'T1110'),

    Service            = 'Graph',
    License            = 'AAD_PREMIUM_P2',
    Author             = 'f-bader'
)]
```

### 2.1 Properties

Types stay within what the AST reader accepts: `string`, `string[]` and `bool`.

| Property | Type | Values | Built-in tests | Notes |
| --- | --- | --- | --- | --- |
| `Id` | string | unchanged | required | |
| `Title` | string | unchanged | required | |
| `Product` | string | a product key or alias from the taxonomy | required | Stored and written to results as the key. Custom tests may use any one-line text up to 40 characters. |
| `RelatedProduct` | string[] | product keys or aliases | optional | Must not repeat `Product`. Resolved like `Product`. |
| `Feature` | string | a feature key of the test's product | required | Custom tests: any one-line text up to 60 characters. |
| `Area` | string | an area key | required | Custom tests: any one-line text up to 60 characters. |
| `ResourceType` | string | a resource type key | required | Pattern `^[A-Za-z][A-Za-z0-9]*$`. Custom tests may use a key that is not in the taxonomy. |
| `Severity` | string | `Critical`, `High`, `Medium`, `Low`, `Info` | required | unchanged |
| `UserImpact` | string | `Low`, `Medium`, `High` | required unless `Severity` is `Info` | Normalised to this spelling. |
| `ImplementationCost` | string | `Low`, `Medium`, `High` | required unless `Severity` is `Info` | Normalised to this spelling. |
| `Mitre` | string[] | `T####`, `T####.###`, or the single value `None` | required | `None` cannot be combined with an ID. IDs are validated against the pinned ATT&CK release by the build and the unit tests, not at run time. |
| `Control` | string[] | `<framework-key>:<control-id>` | not used | Pattern `^[a-z0-9][a-z0-9.\-]*:[^\s,]+$`. For custom tests and packs. |
| `Service` | string[] | unchanged | required | |
| `License` | string[] | unchanged | optional | |
| `Permission` | string[] | one permission per element, no commas | optional | Replaces the reserved name `GraphScope`. Recorded; not enforced in 3.0. |
| `TenantType`, `Cloud`, `Platform` | string[] | unchanged | optional | |
| `Lifecycle` | string | `Preview`, `Stable`, `Deprecated` | optional, default `Stable` | Replaces `Preview`. |
| `ReplacedBy` | string | a test ID | optional | Only meaningful with `Lifecycle = 'Deprecated'`. |
| `Tag` | string[] | unchanged syntax | optional | Free labels. See section 5. |
| `LongRunning`, `Exclusive`, `InstanceSource`, `Author`, `Contributor`, `HelpUrl` | | unchanged | unchanged | |

Removed properties and the error the reader gives for each:

| Property | Message |
| --- | --- |
| `Category` | "`Category` was removed in Maester 3.0. Use `Product` and `Feature`; the result's `Block` is derived from them." |
| `Preview` | "`Preview` was removed in Maester 3.0. Use `Lifecycle = 'Preview'`." |

Both are `InvalidMetadata` with that message, so a preview-era custom test fails loudly with the fix in the text.
`Convert-MtTest` writes the new form.

Reserved names become `OptionalService` and `TimeoutSeconds`. `GraphScope` and `Deprecated` are no longer
reserved: `Permission` and `Lifecycle` took their places.

### 2.2 The taxonomy registry

`powershell/assets/MaesterTaxonomy.psd1` lists the products (with their features and aliases), the areas and the
resource types. Keys are lowercase kebab-case for products, features and areas and PascalCase for resource
types. Display names live only in the registry, so a product can be renamed without touching a test.

- The reader resolves `Product` and `RelatedProduct` through `Key` and `Aliases`, case-insensitively, the same way
  service names resolve through the service registry. `Product = 'Entra ID'` therefore still loads and is stored as
  `entra`.
- For a built-in test, a `Product`, `Feature`, `Area` or `ResourceType` that is not in the registry, or a
  `Feature` that does not belong to the test's `Product`, is `InvalidMetadata`.
- For a custom test, a value that matches the registry is normalised to the key; any other value is kept as written.
- The schema table's `Products` list is removed. The order of `Products` in the registry is the order of the
  console lanes and of product lists in reports.
- `Get-MtTaxonomy` (internal) loads and caches the registry; `Get-MtTestSchema` keeps its role.

`powershell/assets/MaesterAttackTechniques.json` is a trimmed copy of one MITRE ATT&CK Enterprise release:
tactic and technique IDs and names, and the IDs that release retired. The registry's `Attack.Version` names the
release. `build/attack/Update-MtAttackTechniques.ps1` regenerates the file from the official STIX data when the
pin moves.

### 2.3 Derived values

Nothing in this list is typed in a test.

| Value | Rule |
| --- | --- |
| `Suite`, `Source` | From the nearest `suite.json`, as today. |
| `Block` | Kept on the result row for 2.x consumers and for XML test-case names. Native tests: the display name of `Product` when it resolves in the registry; else `Product` as written; else `Feature`; else the suite's `Name`; else `Custom`. Pester-format tests: the `Describe` or `Context` name, as today. |
| Tactics | Looked up from `Mitre` in the pinned ATT&CK file when a consumer needs them. |
| Selection tags | See section 5. |

`Convert-MtTest` writes the `Describe` name of a converted Pester test to `Feature`, so its `Block`, and with it
its CI test-case name, does not change.

## 3. Results and catalog

Every native row gains these fields. Fields that a test does not declare are written as `null` or an empty
list, never omitted.

`Product` (now the key), `RelatedProduct`, `Feature`, `Area`, `ResourceType`, `UserImpact`,
`ImplementationCost`, `Mitre`, `Control`, `Lifecycle`, `ReplacedBy`, `Service`, `License`, `Permission`.

`Tag` on a row holds the authored tags (plus instance tags of a family) and nothing else: no suite tags, no test
ID, no flags.

The result gains one top-level object so a consumer can render names without the module:

```json
"Taxonomy": {
  "Products":      [{ "Key": "entra", "Name": "Entra ID" }],
  "Features":      [{ "Product": "entra", "Key": "conditional-access", "Name": "Conditional Access" }],
  "Areas":         [{ "Key": "authentication", "Name": "Authentication" }],
  "ResourceTypes": [{ "Key": "Tenant" }],
  "Attack":        { "Version": "19.2", "Techniques": [{ "Id": "T1110", "Name": "Brute Force", "Tactics": ["TA0006"] }],
                     "Tactics": [{ "Id": "TA0006", "Name": "Credential Access" }] }
}
```

It lists only the keys and techniques that the rows of that result use. Pester-format rows carry the new fields
as `null`.

The built-in catalog (`Maester.TestCatalog.json`) receives the same properties through the existing generic copy,
plus the full `Taxonomy`. The build fails when a built-in test names a technique that is unknown or retired in
the pinned release.

The console keeps one lane per product. It reads the lane title and order from the registry.

## 4. Selection

`Invoke-Maester` and the `Selection` section of the run config gain typed selectors:

| Parameter | Config key | Matches |
| --- | --- | --- |
| `-Product` | `Selection.Product` | `Product` or any `RelatedProduct`. Aliases resolve. |
| `-Feature` | `Selection.Feature` | `Feature` |
| `-Area` | `Selection.Area` | `Area` |
| `-Severity` | `Selection.Severity` | The effective severity |
| `-Suite` | `Selection.Suite` | `Suite` |

Each takes a list. Values within one selector are alternatives; different selectors must all match, and they
combine the same way with `-Tag` and `-TestId`. `*` wildcards work as they do for tags. `Get-MtTest` takes the
same five parameters. Excluding by attribute is not added in 3.0; `-ExcludeTag` and `-ExcludeTestId` remain.

Default exclusions stop being tags:

- A test with `Lifecycle = 'Preview'` is not run unless `-IncludePreview` is given, any `-Tag` is given, or its
  exact ID is in `-TestId`. This is the 2.x rule for the `Preview` tag.
- `LongRunning` keeps its rule.
- A test whose service is opt-in in the service registry, such as Active Directory, is not run unless that
  service is connected. The `AD` tag no longer decides this.
- `Lifecycle = 'Deprecated'` tests still run. The row says so, and reports may set them apart.

## 5. Tags

Built-in tests ship without taxonomy tags. `Tag` remains for labels a test owner finds useful and for custom tests.

### 5.1 Selecting with 2.x tags

`-Tag CA`, `-Tag CIS`, `-ExcludeTag MS.AAD.3.5` and every other 2.x tag string keep working for the 3.x line.

- `powershell/assets/Maester.LegacyTags.json` maps each 2.x tag to the IDs of the built-in tests that carried it.
  It is generated once from the frozen 2.x snapshot (`powershell/tests/fixtures/golden/tags-and-blocks.json`) and
  from the tags that 3.0 previews carried, and is not edited by hand afterwards. Tests added after 3.0 are not in it.
- When resolving `-Tag` and `-ExcludeTag`, a built-in test's selection tags are its authored `Tag` values, its
  legacy tags from that file, and its own ID. Legacy tags and the ID are used for selection only and are never
  written to a result row.
- The first time a run selects through a legacy tag, Maester writes one warning that names the tag and, where
  the file gives one, the typed selector that replaces it, for example `-Tag CA` → `-Feature conditional-access`.
- A unit test asserts that every tag in the 2.x snapshot still selects exactly the set of test IDs it selected in 2.x.

### 5.2 What replaces each kind of tag

| 2.x tag | Example | Now |
| --- | --- | --- |
| Suite | `CISA`, `Maester` | `-Suite cisa`; `Suite` on the row |
| Product or service | `EXO`, `Entra` | `-Product exchange`; `Product` on the row |
| Topic or theme | `CA`, `AD.User`, `Privileged` | `-Feature conditional-access`, `-Area privileged-access` |
| Benchmark control ID | `MS.AAD.3.5` | `-TestId CISA.MS.AAD.3.5` |
| Benchmark version, level, profile | `CIS M365 v7.0.0`, `L1`, `CIS E3 Level 1` | The suite's framework file (section 6) |
| Licence | `Entra ID P1` | `License` on the row |
| Severity | `Severity:High` | `-Severity High` |
| Lifecycle | `Deprecated`, `Preview` | `Lifecycle` |

## 6. Benchmarks and framework files

A suite that implements a published benchmark says so once, in its `suite.json`:

```json
"Frameworks": [
  { "Key": "cis-m365", "Version": "7.0.0", "IdPrefix": "CIS.M365." }
]
```

The requirement a test implements is the rest of its ID after the prefix, so `CIS.M365.5.2.2.3` implements
requirement `5.2.2.3`. Facts about a requirement that used to be tags live in a framework file beside the suite,
`frameworks/<key>.json`:

```json
{
  "Framework": "cis-m365",
  "Name": "CIS Microsoft 365 Foundations Benchmark",
  "Version": "7.0.0",
  "Requirements": [
    { "Id": "5.2.2.3", "Level": "L1", "Profile": ["E3 Level 1"], "Tests": ["CIS.M365.5.2.2.3"] }
  ]
}
```

- The catalog build validates that every test ID a framework file names exists and that every test of the suite
  with the prefix is listed once.
- A row of such a test gains `Benchmark`: `{ "Framework": "cis-m365", "Version": "7.0.0", "Requirement": "5.2.2.3" }`
  plus the requirement's own facts.
- A row's `Control` list is the test's `Control` values followed by the `Related` references of its requirement.
- Reports say a test supports a control. They do not state compliance with a framework.

Framework files for CIS Microsoft 365, CIS GitHub and CISA SCuBA ship with their suites. The CISA file carries
each policy's revision, SHALL or SHOULD, and the NIST SP 800-53 mapping that ScubaGear publishes.

## 7. Enforcement

1. **Reader and build.** Section 2 rules. An invalid built-in test fails the build.
2. **Unit tests**, `powershell/tests/general/NativeTestAttributes.Tests.ps1`:
   - every built-in test has the required attributes of section 2.1;
   - every key is in the taxonomy and every feature belongs to its product;
   - `UserImpact` and `ImplementationCost` are absent when `Severity` is `Info` and present otherwise;
   - `Mitre` is a valid list for the pinned release, with no technique listed beside one of its own
     sub-techniques, and at most five entries;
   - a test that passes `-GraphObjects` to `Add-MtTestResultDetail` does not declare `ResourceType = 'Tenant'`;
   - no built-in test carries a tag that is a product, feature, area, suite or severity name, a benchmark label
     or a test ID;
   - the taxonomy has no unused or duplicate key, and the folder of a test agrees with its `Product`.
3. **Attribute review.** A pull request that adds a test or changes a rubric attribute is checked by a reviewer
   model against the rubric page. The check fails when a value does not fit, and reports the expected value and
   the reason. The workflow runs trusted code from the base branch only and treats the pull request's files as data.

## 8. Migration

- One script, `build/migration/Convert-MtTestAttributes.ps1`, rewrites the attribute of every built-in test:
  it drops `Category`, turns `Preview` into `Lifecycle`, writes `Product` as a key, removes the 2.x tags and
  merges the values in `build/migration/attributes/*.json`. It is idempotent. EIDSCA and ORCA take their values
  from their generator metadata files and are regenerated, never edited.
- The golden test stops comparing `Block` and tags with the 2.x snapshot and asserts section 5.1 instead.
- `Get-MtTestInventory`, kept for one major version, reports `Feature` where it reported the `Describe` name.

## 9. Compatibility

| Consumer | Effect |
| --- | --- |
| `-Tag`, `-ExcludeTag` with 2.x tags | Unchanged for built-in tests, with a warning once per run. |
| Result `Block` | Changes for built-in tests to the product name. CI test-case names of built-in tests change once. |
| Result `Tag` | Built-in rows no longer list suite, product or benchmark tags or the test ID. Use the typed fields. |
| Result `Product` | Now a key. `Taxonomy.Products` gives the name. |
| Custom native tests written for a 3.0 preview | `Category` and `Preview` are rejected with the replacement in the message. `Convert-MtTest` and `New-MtTest` write the new form. |
| Pester-format tests | No change. |

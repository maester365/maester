# Design: Maester 3.0 native test model and engine

> **Status: DRAFT, nothing has been implemented.** Drafted 2026-10-02 against `main`
> at `d88798d8`; owner rulings of 2026-10-03 applied. Implements the direction in
> [RFC #2050](https://github.com/maester365/maester/discussions/2050), with the engine
> choice made on stability rather than on the RFC's wording.
> Section 16 records the rulings and the one item still open. Section 17 lists what is
> not yet verified. Appendix A holds the detailed rules an implementer needs.

## 1. Summary

Maester 3.0 replaces "Pester wrapper + function + Markdown + config row" with a native
test that is two files, and gives Maester its own engine for discovery, selection,
prerequisites, execution and results. Pester stays as a compatibility provider for
custom tests.

The design in one page:

- **A check is `Test.<ID>.ps1` + `Test.<ID>.md`.** Metadata sits on the function in one
  `[MaesterTest(...)]` attribute with 17 properties (section 4). Tunable values are ordinary
  function parameters, each able to say what kind of thing it holds (a group, a user, a
  Conditional Access policy, an Azure resource group) so a UI can offer a picker
  (section 3.4). Nothing about a built-in check lives in `maester-config.json` or in a
  `.Tests.ps1` file any more.
- **The boilerplate leaves the tests.** The engine catches errors, checks connections,
  licences, tenant type, cloud and platform, and binds parameters. A check is the check:
  no outer `try`/`catch`, no `Test-MtConnection` at the top, no licence lookup.
- **Metadata is read statically.** The engine parses the attribute from the AST and
  validates it against one schema table. No test code runs during discovery, so a test
  catalog can be produced without a tenant, and a typo is an error with file and line
  instead of a silently dropped test.
- **The engine owns prerequisites.** A test declares the services, licences, tenant
  types, clouds and operating systems it applies to. The engine evaluates them once per
  run and writes a `Skipped` row with a reason code. Service, licence and platform gates
  are on in 3.0; tenant type and cloud are detected and recorded, with enforcement
  behind a switch.
- **Selection is by ID as well as by tag.** `-TestId` / `-ExcludeTestId` and a run
  configuration document work for native and Pester tests, so a hosted runner no
  longer has to filter results after the run.
- **One run configuration.** The run config is today's `maester-config.json` format
  grown additively, found by file discovery as today or passed with `-Config` as a path
  or an object. The 700-row `tests/maester-config.json` that ships today is deleted.
- **Existing custom Pester tests keep running** through real `Invoke-Pester`, called
  from inside the module as today, and their rows land in the same report. Pester is no
  longer a dependency of the module; it is loaded only when Pester files are present.
- **The result JSON keeps its 2.x shape.** Same fields, same six `Result` values; new
  fields are additive. Existing consumers of the JSON keep working unchanged. The HTML
  report keeps working, with its Config page updated.
- **PowerShell 7 only.** The manifest requires PowerShell 7.4 and the `Core` edition;
  the Windows PowerShell 5.1 leg of CI goes away. 7.4 is the floor because Azure
  Automation and hosted runners run it today; it leaves Microsoft support on 10 November
  2026, so the floor moves to 7.6 in the first release after those hosts move.
- **A small C# core inside the module.** Scheduling, per-test timeouts, cancellation,
  stream capture and the attribute types are a 40 KB `Maester.Engine.dll` shipped in
  the module; everything else stays PowerShell (section 5.5). In 3.0 it runs tests one
  at a time on the caller's runspace; parallel execution later is the same scheduler
  with worker runspaces switched on.
- **Single-threaded in 3.0, parallel later.** The rules that make that possible are
  adopted now (section 13), and the plan is data, so a host can also run partitions of
  it in other containers and merge the results (section 13.1).
- **Authorship is in the attribute** (`Author`, `Contributor`), seeded once from git
  history before the files move, then maintained by hand.

Section 5.3 lists every place where the row for a test differs from 2.x. Sections 7
and 8 list the changes to which tests run and which config applies.

## 2. What the research found

Counts were scripted over the whole tree at `d88798d8`.

| Finding | Number |
| --- | --- |
| Pester wrapper files under `tests/` | 520 (one is never discovered: it lacks the `.Tests.ps1` suffix) |
| `It` blocks ("checks") | 750, with 742 unique static IDs and 5 families whose IDs are built at run time |
| Exported functions | 739: 683 `Test-*` and 56 others |
| `It` blocks that are one ID, one function, no wrapper arguments | 711 (94.8%), counting the 44 EIDSCA checks |
| Checks convertible by script or by re-templating a generator | 729 of 750 (97.2%); 21 need hand work |
| Check functions with a hand-written "not connected" or "not licensed" skip | 607 of 683 (89%) |
| Check functions with no `try`/`catch` of their own | 370 of 683 |
| Distinct Pester tags | 921: 829 are IDs or control aliases, 92 are real classification |
| Sources of severity today | 3 (config, `-Severity` in code, `Severity:` tag); 25 checks disagree with themselves |
| Config titles that differ from the test's own title | 180 of 683 |
| Separate parsers of test metadata in the repo today | 12 |
| Checks that inspect cloud or tenant type today | 0 |
| Public custom `It` blocks that call a built-in `Test-Mt*` function | 8 of 367 (2.2%); half of them call `Test-MtConditionalAccessWhatIf` |
| Public repos holding stale copies of built-in wrappers | 18 repos, 2,084 files; median copy is 480 days old |

Four things about the current engine matter most:

1. **Pester touches the engine in only a few places**: `Invoke-Pester` in
   `Invoke-Maester`, the conversion in `ConvertTo-MtMaesterResult`, the "which test is
   running" lookup in `Add-MtTestResultDetail`, and skipping via `Set-ItResult`.
   Everything after the result object (HTML, Markdown, CSV, mail, Teams) reads only the
   Maester shape.
2. **Pester test files run inside the Maester module's session state.** They can see
   private functions and `$__MtSession`. The compatibility path must keep calling
   `Invoke-Pester` from a module function, and a private function that is still defined
   keeps stale wrappers working.
3. **PowerShell does not validate attribute arguments when a function is defined.** An
   unknown property or a bad value raises no error at import; reflection silently
   returns nothing and the error only appears when the function is called. The engine
   must validate from the AST.
4. **Pester's `try` around every `It` is doing real work.** Most check functions have no
   `try`/`catch`. A terminating error ends the check today only because Pester catches
   it. The native engine must provide the same wrapper (section 5.2).

What Zero Trust Assessment (ZTA) teaches, from its current `main` (the RFC links the
older `psnext` branch):

- The model works: 336 tests, one `[ZtTest]` per file, AST discovery, `.md` split on
  `<!--- Results --->`.
- Worth copying: the attribute idea, AST discovery, the Markdown contract, `Service` as
  all-of, `CompatibleLicense` as "any element, `&` inside an element means all", tenant
  type from `organization.tenantType`.
- Worth avoiding: free-text fields that drifted (53 categories, 49 spellings of minimum
  licence); the result helper accepting title and risk again, so 112 tests now show a
  different title from their attribute; optional `Service`, which 174 tests omit; no
  cloud property, so 27 tests hand-code environment checks; tenant-type mismatches
  dropped with no result row.

## 3. The test format

### 3.1 Files, names and layout

- A check is `Test.<ID>.ps1` and `Test.<ID>.md` in the same folder. The ID is used
  verbatim: `Test.MT.1198.ps1`, `Test.CISA.MS.AAD.3.5.ps1`, `Test.AD-USER-07.ps1`.
- **IDs do not change.** They are keys in user configs, in result history kept by
  hosted runners, and in docs URLs.
- **ID grammar for `[MaesterTest(Id)]`:** segments of letters and digits (and `_` after the
  first segment) separated by `.` or `-`, starting with a letter, containing at least
  one digit or separator, unique case-insensitively
  (`^(?=.*[0-9.\-])[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$`), and at most 64
  characters. All existing built-in
  IDs match, as do the documented custom style `CT0001` and every static ID found in
  public custom tests, so a custom Pester test can be converted without renaming.
- The grammar applies to native test declarations only. A Pester test's ID is taken as
  written (the text before the first colon of the `It` name, or the whole name), and
  IDs in the run config are free text.
- **Reserved prefixes.** `MT.`, `CISA.`, `CIS.`, `EIDSCA.`, `ORCA.`, `AD-`, `AZDO.` and
  `MT1060.` belong to built-ins. A custom test whose ID uses one of these prefixes but
  is not a built-in ID still runs, with one warning listing those IDs. An ID that
  equals a built-in ID follows the collision rules in section 8. Custom tests should
  use their own prefix (`CONTOSO.1001`).
- One `[MaesterTest]` function per file. **The function keeps today's descriptive name**
  (`Test-MtAppRegistrationCertificateLifetime`). That keeps git blame and stale wrapper
  copies working.
- **A function that serves several IDs today** (9 functions, 22 IDs) keeps its name,
  signature and body, moves to `powershell/internal/` as a shared helper, and gets one
  thin `Test.<ID>.ps1` per ID that calls it with literal arguments. Each thin test
  function gets a new unique name, recorded in the ID map. An attribute cannot carry a
  hashtable of arguments, and those arguments must not be user-configurable. The 44
  EIDSCA checks already have one function per ID; the generator emits them as native
  files.
- **Where the wrapper holds the verdict today**, that comparison moves into the
  `[MaesterTest]` function, so every `[MaesterTest]` function returns `$true` for Passed. Where a
  2.x-named function would otherwise have to change what it returns, it keeps its
  return value and a thin `Test.<ID>.ps1` does the comparison. This affects 17 wrappers
  that assert `Should -Be $false` and the EIDSCA value comparisons (section 14).
- Source layout: `tests/<suite>/[<area>/]Test.<ID>.ps1`, with one `suite.json` per suite
  folder (section 3.6). AZDO checks move to `tests/azdo`.
- Built module: internal files (including the attribute class), public functions and
  then the native tests are concatenated into `Maester.psm1`. Test functions are defined
  in module scope. A build-time catalog (`Maester.TestCatalog.json`) and the Markdown
  bundle keyed by ID ship beside it.
- **Function names must be unique** across `internal/`, `public/` and all built-in test
  files, because they share one module scope where a later definition silently replaces
  an earlier one. The build fails on a duplicate.

### 3.2 The attribute

```powershell
# Shown as PowerShell for readability. The shipped type is MaesterTestAttribute in
# Maester.Engine.dll (section 5.5), with exactly these properties.
# The engine reads [MaesterTest(...)] from the AST only and validates it against one schema table.
class MaesterTest : System.Attribute {
    # Identity
    [string]   $Id                  # required
    [string]   $Title               # required
    [string]   $Severity            # Critical | High | Medium | Low | Info

    # Classification
    [string]   $Category            # report grouping (today's Describe name)
    [string[]] $Tag                 # free tags for -Tag / -ExcludeTag
    [bool]     $Preview
    [bool]     $LongRunning

    # Applicability
    [string[]] $Service             # ALL must be connected
    [string[]] $CompatibleLicense   # ANY element; 'A&B' inside an element = all of
    [string[]] $TenantType          # Workforce | External
    [string[]] $Cloud               # Commercial | GCC | GCCHigh | DoD | China | Bleu | Delos | GovSG
    [string[]] $Platform            # Windows | Linux | MacOS

    # Execution
    [string]   $InstanceSource      # makes the test a family (section 10)
    [bool]     $Exclusive           # must not run concurrently with another test

    # Credits and docs
    [string[]] $Author
    [string[]] $Contributor
    [string]   $HelpUrl
}
```

Authoring rules, enforced by the engine and by a unit test:

- Exactly one `[MaesterTest]` per file. Named arguments only. Constants only: `'a'`,
  `('a','b')`, `$true`, or a bare flag such as `LongRunning`. No `@()`, variables,
  expressions or hashtables.
- At the top level a test file contains only function definitions: the `[MaesterTest]`
  function, an optional `InstanceSource` function, and private helpers. Any other
  top-level statement is invalid. This is what makes "never execute during discovery"
  true for the marketplace later.
- Invalid metadata is an `Error` row with reason `InvalidMetadata`, file and line. The
  function is never invoked. For an unknown property or value the message adds that it
  may come from a newer Maester. One exception: an unregistered `Service` name in a
  custom test is not invalid metadata; it gives `Skipped`/`ServiceNotRegistered`
  (section 6).

### 3.3 Worked example: MT.1198

Today this check is a function file, an `It` in a wrapper under
`Describe 'Maester/Entra' -Tag 'App','Entra','Graph','LongRunning','Maester'`, a config
row with `Severity: Medium`, and a `.md`. In 3.0 it is
`tests/Maester/Entra/Test.MT.1198.ps1` plus the `.md`:

```powershell
function Test-MtAppRegistrationCertificateLifetime {
    <#
    .SYNOPSIS
    Check if app registrations use certificates that are issued with an excessive validity period.
    .LINK
    https://maester.dev/docs/tests/MT.1198
    #>
    [MaesterTest(
        Id       = 'MT.1198',
        Title    = 'App registration certificates should not have excessive validity periods.',
        Severity = 'Medium',
        Category = 'Maester/Entra',
        Tag      = ('App', 'Entra', 'Graph'),
        LongRunning,
        Service  = 'Graph',
        Author   = 'simon-vedder'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest validity period, in days, that a certificate may be issued for.
        [ValidateRange(1, 3650)]
        [int] $MaximumValidityDays = 365
    )

    # ... today's function body, unchanged ...
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}
```

The `Maester` suite tag comes from `tests/Maester/suite.json`. The wrapper `It` and the
config row are deleted, and so are the function's leading `Test-MtConnection Graph`
guard and its outer `try`/`catch` (section 5.2). `MaximumValidityDays` becomes
configurable per run without any wrapper. This syntax, including the bare flag and a single string for a `string[]`
property, was verified to load and to be readable from the AST on PowerShell 7.4 and
7.6.

### 3.4 Test parameters

A test's `param()` block is the schema for its tunables: users or groups to exclude,
policies to scope to, thresholds, switches. Values come from the run config
(`TestSettings[].Parameters`) or from `Invoke-MtTest -Parameter`, never from a wrapper.
Pester gave no way to do this; in 3.0 it is how a test is customised.

Rules, enforced by a unit test for built-ins and reported as `InvalidMetadata` for
custom tests:

- `[CmdletBinding()]` is required.
- Allowed types: `int`, `bool`/`switch`, `string`, `string[]`.
- Defaults are constants. No mandatory parameters: a test must run with an empty
  config, and PowerShell would otherwise prompt inside the engine.
- Every parameter has a description (a comment above it or `.PARAMETER` help);
  thresholds carry `ValidateRange`.
- **Engine-owned names:** `Instance` and every name starting with `Mt` are reserved.
  They cannot be set from config. 3.0 supplies only `$Instance`, and only to families.

Today 49 check functions declare parameters; 66 of those parameters on 40 functions are
real user knobs that no wrapper ever sets.

**Telling a UI what a parameter is.** A `[MaesterParameter]` attribute on the parameter
declares its semantic kind:

```powershell
param(
    # Members of these groups are exempt from this check.
    [MaesterParameter(Kind = 'Entra.Group')]
    [string[]] $ExcludedGroups,

    # Only evaluate these Conditional Access policies. Empty means all.
    [MaesterParameter(Kind = 'Entra.ConditionalAccessPolicy')]
    [string[]] $PolicyIds,

    [ValidateRange(1, 3650)]
    [int] $MaximumValidityDays = 365
)
```

- `Kind` names an entry in the **parameter-kind registry**, engine data that ships in
  the catalog. A kind defines: the value shape the test receives (a Graph object ID, a
  UPN, an ARM resource ID, a plain string), a validation pattern, the service the value
  belongs to, how to resolve a display name (an endpoint template), and a UI hint for
  pickers (`graph-object` with an `@odata.type`, `arm-resource` with a resource type,
  `enum`, `text`, `number`, `boolean`).
- Initial kinds: `Entra.User`, `Entra.Group`, `Entra.ServicePrincipal`,
  `Entra.Application`, `Entra.ConditionalAccessPolicy`, `Entra.NamedLocation`,
  `Entra.Domain`, `Entra.DirectoryRole`, `Azure.Subscription`, `Azure.ResourceGroup`,
  `Azure.Resource`. A parameter without `[MaesterParameter]` is its primitive type, and a
  `ValidateSet` is an enum.
- **Plugin model.** A kind is a data record plus an optional resolver function. The
  engine ships its kinds in `parameter-kinds.psd1`; a package registers more in its
  manifest under its own prefix (`Contoso.Site`). A UI (a hosted portal, the report's
  Config page) reads the kinds from the catalog, picks a picker by UI hint, and falls
  back to a text box for a kind it does not know. Adding a kind changes no test file
  and no engine code.
- **What the engine does with a kind.** It validates the value shape before the test
  runs (a malformed GUID is `InvalidConfiguration`, section 7.3), passes the ID to the
  test as a plain string, and echoes the effective parameters on the result row with a
  resolved `DisplayName` when the kind's service is connected, so the report can say
  "excluded groups: Finance" rather than a GUID. The catalog lists every parameter
  with its name, type, kind, default, allowed values, range and description.
- **Config value shape.** A string ID, or an object `{ "Id": "...", "DisplayName":
  "..." }` for UIs that store names; arrays of either for `string[]`. The test always
  receives IDs.

Accepted entities per test (issue 1798: "ignore these users") is an ordinary parameter
of kind `Entra.User`; the test decides how to apply it and the row records what was
ignored.

### 3.5 The Markdown file

Same contract as ZTA: no front matter; the description; `#### Remediation action`;
optional `#### Related links`; then exactly one `<!--- Results --->` followed by
`%TestResult%`. The converter appends the two-line footer to the 366 files that lack
it. That is behaviour-neutral: the helper already falls back to the raw result when the
placeholder is missing.

### 3.6 The suite manifest

Each suite folder has a small `suite.json` for what is true of every test in the suite:

```json
{
  "Id": "CISA",
  "Name": "CISA SCuBA baselines",
  "Source": "CISA",
  "Tags": ["CISA"],
  "DefaultCategory": "CISA",
  "Categories": ["CISA"],
  "IdPattern": "^CISA\\.",
  "HelpUrlTemplate": "https://maester.dev/docs/tests/{Id}",
  "Upstream": { "Name": "CISA ScubaGear", "Url": "https://github.com/cisagov/ScubaGear" }
}
```

- `Source` is written to each result row and is a closed list that existing consumers
  of the result JSON already classify by: `Maester`, `CISA`, `CIS`, `EIDSCA`, `ORCA`,
  `Custom`. AD, AZDO and XSPM
  declare `Maester`. Appendix A.6 gives the full rule, including Pester rows.
- `suite.json` may carry `"RequiresMaester": "3.2"`. A single custom file can state the
  same with a standard `#Requires -Modules` line, which the engine reads statically. If
  the running engine is older, the affected tests get one row each with reason
  `RequiresNewerMaester` instead of one schema error per unknown property.
- Unknown `suite.json` keys are ignored with a warning.
- The marketplace package manifest plays this role for packages (section 12.2).

### 3.7 Custom tests

A user writes the same two files in their own folder, by default `Custom/`:

```text
Custom/
  Test.CONTOSO.1001.ps1
  Test.CONTOSO.1001.md
  suite.json          (optional: tags, category and source for every test in the folder)
  maester-config.json (optional)
```

- `New-MtTest -Id CONTOSO.1001 -Title '...' -Service Graph -Path ./Custom` scaffolds
  both files. `Invoke-MtTest -Path ./Custom/Test.CONTOSO.1001.ps1` runs one file
  through the engine; `Get-MtTest -Path ./Custom` validates a folder and reports every
  problem with file and line.
- A custom test is run exactly like a built-in: same applicability gates, same
  parameter binding and config overrides, same report rows. Its `Source` is `Custom`
  unless a `suite.json` says otherwise (section 3.6).
- The file is loaded into its own private module (section 5.1). It can call every
  exported Maester command: `Invoke-MtGraphRequest`, `Add-MtTestResultDetail`,
  `Get-MtSetting`, `Get-MtTenantContext`, `Test-MtConnection`,
  `Get-MtLicenseInformation`, `Get-MtUser`, `Get-MtConditionalAccessPolicy` and the
  rest of the public surface (section 12). It cannot call Maester's private functions.
  Helpers shared between several custom files live in a helper file that each test
  dot-sources from inside the function.
- `Invoke-Maester` discovers custom tests under `-Path` (section 7.2). Pester-format
  custom tests in the same folder keep working (section 8); a Pester test that needs a
  built-in's verdict calls `Invoke-MtTest -Id MT.1005`.
- A custom test uses its own ID prefix. Built-in prefixes are reserved (section 3.1).

## 4. The consolidated attribute list

"Migrated from" is where the converter takes the value. Every property has a consumer
in 3.0 except `Exclusive`, which is recorded in the catalog and first used by the
parallel scheduler. Parameter kinds are declared with a second attribute on the
parameter itself (section 3.4), not here.

| # | Property | Type | Allowed values | Required | Default when omitted | Description | Migrated from | ZtTest equivalent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `Id` | string | ID grammar (3.1) | yes | — | Stable identifier. File is `Test.<Id>.ps1` | `It` name before the first colon | `TestId` (int) |
| 2 | `Title` | string | one line | yes | — | The only title | `It` name after the colon (wrapper title wins over config title) | `Title` |
| 3 | `Severity` | string | Critical, High, Medium, Low, Info | built-ins, except checks that compute it at run time (MT.1182) | empty | Default severity; run config may override | config row, else a literal `-Severity` in code, else `Severity:` tag | `RiskLevel` |
| 4 | `Category` | string | the suite's `Categories`; free text for a test with no suite manifest | built-ins, unless the suite has a default | suite default, else `Custom` | Report grouping; written to the result as `Block` | `Describe` name | `Category` (free text in ZTA) |
| 5 | `Tag` | string[] | non-empty; no commas; inner spaces allowed | no | none | Free selection tags | Pester tags, minus the ID, suite tags and the two flags | none (`Pillar`, `SfiPillar` map here) |
| 6 | `Preview` | bool | — | no | false | Not run unless `-IncludePreview` or any `-Tag` | `Preview` tag (28 checks) | none |
| 7 | `LongRunning` | bool | — | no | false | Not run unless included (section 7.1) | `LongRunning` tag (30 checks) | none |
| 8 | `Service` | string[] | names in the service registry, or `None` | built-ins | no requirement | Services that must **all** be connected | leading `Test-MtConnection` guards; inferred for unguarded functions | `Service` (optional in ZTA) |
| 9 | `CompatibleLicense` | string[] | Microsoft service plan names; `&` joins plans | no | no requirement | Tenant needs **any one** element | `Get-MtLicenseInformation` checks; wrapper `-Skip` | `CompatibleLicense` |
| 10 | `TenantType` | string[] | Workforce, External | no | Workforce | Tenant types the test applies to | new | `TenantType` (mandatory in ZTA) |
| 11 | `Cloud` | string[] | Commercial, GCC, GCCHigh, DoD, China, Bleu, Delos, GovSG | no | all clouds | Clouds the test is valid in | new | none |
| 12 | `Platform` | string[] | Windows, Linux, MacOS | no | all platforms | Operating systems the test can run on; the engine skips it elsewhere (section 6) | new; maintainers annotate, lint flags Windows-only calls | none |
| 13 | `InstanceSource` | string | function name in the same file | no | single result | Makes the test emit one row per instance | `BeforeDiscovery` + `-ForEach` | none |
| 14 | `Exclusive` | bool | — | no | false | Must run alone (for example, it writes to the tenant) | new | none |
| 15 | `Author` | string[] | GitHub handles | built-ins: at least one | none | Initial author(s) | authorship seed (section 11) | none |
| 16 | `Contributor` | string[] | GitHub handles, in order of first contribution | no | none | Secondary contributors | authorship seed | none |
| 17 | `HelpUrl` | string | https URL | no | suite template | "Learn more" link | `See https…` suffix of the `It` name | none |

**Tags.** The effective tag set of a test is: suite tags + `Id` + `Tag` +
`Preview`/`LongRunning` when set. A golden file, committed before the migration starts,
freezes for every existing ID the tag set Pester selects on today (all ancestor
`Describe`/`Context` tags plus the `It` tags) and its `Block`. The migrated test must
reproduce both, so today's `-Tag` strings select the same tests.

- Existing tags are kept verbatim, including the 14 that contain spaces (`CIS E3 Level
  1`, `Entra ID P1`, `SharePoint Online`; 79 checks carry one) and the `Severity:*`
  tags on 14 checks.
- CISA licence tags stay in `Tag` even where they also seed `CompatibleLicense`.
- Two rows (MT.1022, MT.1023) gain two tags in the result's `Tag` array, because 2.x
  drops `Describe` tags for tests nested in a `Context`. This is a listed difference.

**Deliberately not in the attribute:**

| What | Where it lives instead | Why |
| --- | --- | --- |
| Description, remediation, result template | `Test.<ID>.md` | Prose; same contract as ZTA |
| Tunable values (thresholds, switches, objects to include or exclude) | the function's `param()` block, with `[MaesterParameter(Kind)]` for the UI | Owner position on PR 1804: parameters are declared on the test |
| Enable/disable, severity override, parameter values, accepted risk | run config | User policy is not test metadata |
| Suite, suite tags, result `Source`, help URL template, upstream credit | `suite.json` | Same for every test in a suite |
| Which services are session-bound or opt-in, and how to probe them | service registry (engine data) | Engine knowledge, not test knowledge |
| Licence plan equivalents (`_GOV`, EDU variants) | engine licence table | One place, testable |
| Graph permission scopes | central `Get-MtGraphScope`, as today; the build copies its lists into the catalog | Not asked for; derivable later |
| Framework control mappings (CISA `MS.AAD.3.5` aliases, CIS level) | plain tags in 3.0 | A structured mapping can be added later |

**ZtTest properties not adopted:** `MinimumLicense` (never enforced in ZTA, 49
spellings, documented there as replaced by `CompatibleLicense`); `Pillar` and
`SfiPillar` (become tags on import); `ImplementationCost` and `UserImpact` (no data for
Maester's checks and no consumer). `RiskLevel` is renamed `Severity` because that is
the name Maester users, the report and downstream consumers already use.

**Porting between Maester and ZTA.** The attribute converts mechanically: `TestId` to
`Id = 'ZT.<n>'`, `RiskLevel` to `Severity`, `Pillar`/`SfiPillar` to tags, an omitted
`Service` to `Graph`. The `.md` files port unchanged. Function bodies do not convert
mechanically: ZTA tests report a status through the helper and return nothing, and
some take an injected database.

**Reserved names, additive to the format:** `Product`, `GraphScope`, `OptionalService`,
`TimeoutSeconds`, `Deprecated`. Adding one does not break existing tests. Populating one
is another scripted pass over the files it applies to: `GraphScope` 272 tests,
`OptionalService` the 67 ORCA checks, `Product` nearly all of them unless it is
delivered as a per-suite mapping.

### How the attribute is implemented

- `MaesterTestAttribute` and `MaesterParameterAttribute` are C# types in `Maester.Engine.dll`
  (section 5.5), declared in the global namespace: PowerShell resolves `[MaesterTest(...)]`
  only against the global namespace, so a namespaced type fails at call time. The
  types are loaded with the module (`NestedModules`) and are visible in every
  runspace, to custom files and to packages, with no type accelerator and no
  `ScriptsToProcess` (which breaks when the module is imported inside a function, as
  the published 2.2.85 shows for the ORCA classes).
- The engine still loads custom native test files itself, each into a private dynamic
  module bound to the running Maester instance (section 5.1): that is what keeps a
  custom file from shadowing engine functions and what binds its `Add-MtTestResultDetail`
  calls to the right module instance. Verified on PowerShell 7.4 and 7.6.
- The supported authoring loop is `Invoke-MtTest -Path ./Test.CONTOSO.1001.ps1`.
  Dot-sourcing a test file at the prompt defines the function but gives it no engine.

## 5. The engine

### 5.1 Pipeline

```text
Invoke-Maester
 1 Resolve config      code defaults < one source (-Config, else MAESTER_CONFIG, else discovered files) < parameters
 2 Build context       one provider per fact: services, licences, tenant type, cloud, auth
 3 Discover (static)   built-in native tests: shipped catalog (AST of tests/ in a source checkout)
                       built-in Pester files, custom native tests and Pester files under the custom root: AST scan
 4 Validate + dedupe   engine version, schema, duplicate IDs and function names, .md pairing; ID collisions (section 8)
 5 Select              enabled, IDs, tags, Preview / LongRunning, opt-in services      -> NotRun + reason
 6 Applicability       tenant type, cloud, platform, service, licence; bind parameters -> Skipped | Error
                       -DryRun stops here
 7 Execute             native: one work item per test, in catalog order
                       Pester: one Invoke-Pester call from module scope, only if Pester files are in the plan
 8 Normalise           one row model; severity overrides; dispositions; counts
 9 Emit                JSON, HTML, Markdown, CSV/XLSX, NUnit/JUnit, mail, Teams, -PassThru
```

Two objects are passed through the stages as data:

- **Run context**: run ID, the resolved config, the tenant context, the catalog, the
  plan and a result store keyed by test ID.
- **Tenant context**: built once, immutable and serialisable. `TenantId`, `TenantName`,
  `TenantType`, `Cloud`, per-service connection state, licence state with service plan
  names, plan IDs and SKU IDs, auth type and scopes. It is echoed into the result as
  `TenantContext`. Each fact comes from its own provider function, and the run config
  can force any fact.

The tenant-specific config file needs the tenant ID, so config is resolved in two
passes. The first resolves everything except the tenant file. The engine then reads
the tenant ID from the connection, merges the tenant file, and only then detects the
remaining facts and builds the context, so a tenant file can also force `Environment`
values.

Where test code is loaded:

| Kind | Scope |
| --- | --- |
| Built-in native tests | Maester module scope (in the psm1) |
| Built-in Pester files (unmigrated suites, during the previews only) | `Invoke-Pester` from a module function; shipped in a separate `builtin-pester/` folder that is empty at 3.0.0 |
| Custom native tests | a private dynamic module per file, created by the engine and bound to the running Maester instance. They see Maester's exported commands, not its private functions |
| Custom Pester files | `Invoke-Pester` called from a module function, as today |

A custom native file is loaded by path, so `$PSScriptRoot` resolves. A helper defined in
another test file is not visible; to share code, dot-source a helper file inside the
test function.

### 5.2 The test contract

Test bodies keep today's contract: return `$true` or `$false`, and call
`Add-MtTestResultDetail`. What they no longer contain: the outer `try`/`catch` that
turned every exception into `-SkippedBecause Error`, and the connection and licence
guards at the top. The engine does both. A test may still use `try`/`catch` where it
handles a specific condition, and may still call `-SkippedBecause` for a condition only
it can see.

| The test does | Result | Reason code |
| --- | --- | --- |
| returns `$true` / `$false` | Passed / Failed | — |
| `Add-MtTestResultDetail -Investigate` | Investigate, over any return value including `$null` | — |
| `-SkippedBecause <code>` | Skipped; the call ends the test, as today | `TestSkipped`; `NotApplicable` when that is the code |
| `-SkippedBecause Error`, or any terminating error | Error | `TestError` |
| returns `$null` with no skip and no `-Investigate` | Skipped | `NoResult` |
| returns a non-boolean, or more than one object | Error | `InvalidReturn` |
| exceeds a configured timeout | Error | `Timeout` |

Order of evaluation, as in 2.x: `-SkippedBecause Error`; `-Investigate`; any other skip;
an uncaught error; the returned value.

How a test is invoked:

- **The engine owns the `try`.** Each test runs in a nested pipeline in the current
  runspace, and the nested script wraps the call in `try`/`catch`. Any terminating
  error ends the test and becomes an `Error` row with the exception message as
  `ReasonDetail` and the record in `ErrorRecord`, which is what the boilerplate
  `catch { Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_ }` produced.
  The wrapper is also what makes a statement-terminating error end the test: without
  it, a failed Graph call or a method call on `$null` ends only that statement, the body
  carries on with empty data and can return `$true`. 370 check functions have no
  `try`/`catch` of their own today. A parity run on a healthy tenant would not reveal
  this, so the unit tests include a frozen set of error-path fixtures. The nested
  invocation sets its own `$ErrorActionPreference` and `$WarningPreference`, because a
  nested pipeline runs in the caller's scope and a caller's `Stop` preference would
  otherwise turn a test's `Write-Error` into a terminating error (observed in the
  spike).
- **Streams.** A nested pipeline exposes only the error stream. The nested script
  merges warning, verbose, debug and information records into its output, and the
  engine re-emits them on `Invoke-Maester`'s own streams. Interactive output,
  `3>&1 6>&1` (what a hosted runner captures) and `-WarningVariable` then behave as in
  2.x.
  Warnings and non-terminating errors are also stored on the row as `Diagnostics`.
  `-ErrorAction Stop` is not forced on test bodies.
- **Skip.** `-SkippedBecause` must keep terminating the test: 150 call sites have no
  `return` after it, and 134 ORCA sites are followed by a typo that would error if
  reached. In native mode the helper throws a record with a fixed error ID that the
  engine recognises. The helper's existing re-throw guard is extended to that ID, so a
  skip raised inside a test's own `try`/`catch` survives; 17 functions rely on this.
- **`Add-MtTestResultDetail`** keeps its parameters and picks its mode automatically.
  Under the native engine it stores by test ID and finds the `.md` by ID. Under Pester
  it behaves exactly as today.
- **Severity and title.** Severity is, in order: the run-config row, the attribute,
  then a `-Severity` passed to the helper. The attribute replaces today's config row,
  so this is the 2.x order, and a run-time `-Severity` only takes effect where the
  attribute value is empty (MT.1182). For a family instance the order is: a run-config
  row on the instance ID, one on the parent ID, the instance object's `Severity`
  (section 10), the family's attribute, then the helper's `-Severity`. The title is the
  attribute's; for a family instance it is the instance object's `Title`, else
  `-TestTitle`, else the attribute's. Outside families `-TestTitle` is ignored under
  the native engine. `-Severity` and `-TestTitle` on the helper are a lint error in new
  single-result tests. `-Description` in code still overrides the `.md` description,
  as today.
- **Engine frames use a reserved variable prefix.** A built-in test can read the local
  variables of the functions that called it. 78 check functions read a variable before
  assigning it, so the engine's run loop names its locals with a `$__mt` prefix, as
  Pester does.
- **Timeout.** Available but off by default in 3.0.0 (`Execution.TestTimeoutSeconds`).
  The C# core stops the test's pipeline at the deadline (`BeginStop`; measured 1 to
  2 ms after the deadline for a sleeping test). A blocking .NET call cannot be
  interrupted on .NET Core: on the caller's runspace the engine waits for it; on a
  worker runspace the engine reports the row at the deadline, abandons that runspace
  and replaces it. A test whose deadline fired is `Error`/`Timeout` even if it later
  returned a value. In the available result files no test exceeded 300 seconds.
  Unattended hosts should set 300 seconds; a host that reaps a run after a period of
  console silence must keep every per-test timeout below that period, because a test
  prints nothing while it runs.

### 5.3 Result differences from 2.x

These are the intended differences. They form the parity allow-list (section 14) and
the release notes.

1. **Uncaught exceptions are always `Error`.** 2.x reports `Error` only for five
   exception types and `Failed` for everything else. A native test has no assertion,
   so a throw is never a verdict. `FailedCount` falls and `ErrorCount` rises for those
   rows: 275 of 2,059 `Failed` rows in the available results, 268 of them an ORCA
   "type not found" failure. Pester rows keep the 2.x rule. Most exceptions in built-in
   checks were already `Error` rows through the boilerplate `catch`; those rows look
   the same in 3.0, only without the `TestSkipped = Error` marker, and by default they
   neither fail the run nor the CI test file (`Output.ErrorsAsFailures`, appendix A.2).
2. **A `$null` return with no skip is `Skipped`/`NoResult`.** 2.x reports `Passed`
   where the wrapper has a null guard and `Failed` where it pipes straight into
   `Should`. Thirteen functions use `$null` to mean "not applicable" (8 Global Secure
   Access, 5 AD), all behind null-guard wrappers; they are rewritten to
   `-SkippedBecause NotApplicable` (a new value in the helper's set) and change from
   Passed to Skipped. A `Failed` to
   `Skipped` change is not allow-listed: the parity differ flags it and the function is
   fixed.
3. **A family that is deselected, gated, empty or failed gives one row on the parent
   ID** (section 10).
4. **MT.1022 and MT.1023 gain two tags** in the result's `Tag` array (section 4).
5. **64 checks with no `.md` today** get a generated description.
6. **A Pester file that fails discovery, or a custom native file that fails to load,**
   gives one `Error` row with reason `LoadFailed` per statically known ID in that file.
   Today a failed Pester file gives no rows.
7. **Top-level `Result`** keeps the 2.x meaning: `Failed` if any row is `Failed`, or the
   Pester run reported `Failed`, or any `Error` row was raised by the engine itself
   (invalid metadata or configuration, a file that failed to load, a duplicate ID, a
   newer engine required, a foreign module). A test that threw does not fail the run
   unless `Output.ErrorsAsFailures` is set, which matches 2.x, where nearly every
   exception went through `-SkippedBecause Error` and did not fail the run.
8. **Tenant-specific config files are merged**, not substituted (section 7.4).
9. **`HelpUrl` is filled from the suite template** for the roughly 510 rows whose `It`
   name has no `See https…` suffix. 2.x leaves it empty.
10. **A check with no connection guard today** whose declared `Service` is not connected
    is `Skipped`/`ServiceNotConnected`. 2.x reports `Failed` or `Error`.
11. **Two selection fixes** (section 7.1). A caller's
    `PesterConfiguration.Filter.ExcludeTag` is honoured; 2.x discards it whenever a
    default exclusion applies, so those tests ran. `-Tag All` and `-Tag Full` select
    tests instead of none.

### 5.4 Console output

`-Verbosity` keeps its values. Pester prints no per-test start line, nothing at `None`,
and at `Normal` only failures plus one line per passing file. Native tests have no
files, so the native engine defines its own levels:

| Level | Native engine output |
| --- | --- |
| `None` | no per-test output (as today) |
| `Normal` | one line per finished test: result, ID, title, duration; for Failed and Error also the first error line |
| `Detailed` | also `Running <Id>` when a test starts |
| `Diagnostic` | also engine stage records |

Lines go to the information stream, as Pester's do. Hosts should treat any record as
proof of life rather than parse the text. The contract is "at least one record per
finished test at `Normal` or above", not a line format.

### 5.5 Implementation language: a small C# core inside the module

**Decision.** The scheduling core of the engine is C#, shipped as `Maester.Engine.dll`
inside the Maester module (`NestedModules`), with its source in the repository. It is
not a separate engine product in its own repository
and it does not depend on PSFramework. Everything that is not scheduling stays
PowerShell.

**In C# (about 700 lines in the spike):**

- the attribute types `MaesterTestAttribute` and `MaesterParameterAttribute`;
- the scheduler: one `PowerShell` object per work item; the main lane nested on the
  caller's runspace; worker lanes on a `RunspacePool` whose initial session state
  imports the Maester manifest, with items invoked in module scope so private
  functions resolve; `MaxParallel`; `Exclusive`;
- per-test deadlines (`BeginStop` from a timer, never a synchronous `Stop`), Ctrl+C
  (`StopProcessing` stops every in-flight pipeline), and an abandon-and-replace
  policy for a worker runspace stuck in a blocking .NET call;
- per-item capture of output, error, warning, verbose and information streams, and
  marshalling of progress and information records to the cmdlet's thread, which is the
  only thread allowed to write to the pipeline;
- typed results (`MtRunStatus`, `MtRunResult`), a process-wide result store
  (`ConcurrentDictionary`), and the "current test" identity keyed by runspace ID.

**In PowerShell:** `Invoke-Maester` and the stage orchestration, config resolution,
static discovery and validation, the tenant-context providers, lane assignment from
metadata, the Pester provider, result normalisation, reports, connections, helpers,
and the tests.

**Why C# for that part, from the evidence:**

- PSFramework, which ZTA builds on, moved its worker orchestration from a PowerShell
  loop to C# in June 2026 (`RSAgent.cs`, "orchestrated in C# and implements timeouts /
  activity") because per-item timeouts and idle detection could not be done in the
  PowerShell loop. Its timeout is still a synchronous `Stop()` surfaced as an
  exception that ZTA detects by string matching.
- Pester 6's `Run.Parallel` is pure PowerShell over a runspace pool. It has no per-file
  timeout, and it shipped races in shared session state (issue 3047, PR 2901) and lost
  results (issue 3011) across three releases.
- ZTA had to `Add-Type` a C# timer to time out main-thread tests, disables Ctrl+C
  during shutdown, polls a message log to map runspaces to tests, and never solved
  module import into workers (the `#TODO: This is brittle` comment).
- The spike (appendix B) built the core in a day and ran it on PowerShell 7.6 and on
  a PowerShell 7.4 Linux container: 14 tests with sleeps, a hang, a throw, a stray `break`,
  an `exit`, stream writes and a shared store gave the expected 13 statuses in every
  mode; a hanging test was reported `Timeout` 1 to 2 ms after its deadline; a real
  SIGINT stopped five in-flight tests and closed the pool 56 ms after the signal; every
  progress record was written on the cmdlet thread while tests ran on five others;
  200 trivial tests cost 0.1 ms each.
- The attribute needs a compiled type anyway (section 4), so the DLL adds no new
  category of artefact.

**3.0 behaviour.** `MaxParallel = 1` means no pool and no second runspace: every test
runs nested on the caller's runspace, with the caller's authentication and module
instance, so Exchange, Teams and SharePoint sessions work exactly as today. That is
the default in 3.0.0. The scheduler, timeouts, cancellation and stream capture are
nevertheless the code that runs, so switching parallel execution on later is a
default change plus the session verification in section 13, not a second engine.

**Rules the implementer inherits from the spike:**

- The attribute types live in the global namespace.
- Cmdlet writes happen only on the pipeline thread; workers post events to a queue.
- Nested pipelines are invoked synchronously and set their own preference variables.
- Stop pipelines with `BeginStop`; read stream collections by index, never with
  `foreach` on a live collection; start a deadline inside the runspace, and pre-warm
  a pool before timing anything.
- The DLL has no dependencies, so it loads in the default assembly load context on
  PowerShell 7 and needs no isolation layer.

**Costs, stated plainly:**

- The dotnet SDK is needed only to change the engine. The built DLL (40 KB,
  deterministic build) is committed under `powershell/lib/`, and CI rebuilds it and
  fails if the bytes differ from the committed file. Test authors and most
  contributors never build it.
- After updating Maester in a running session, PowerShell must be restarted: a
  rebuilt or newer DLL at the same path is silently ignored by `Import-Module -Force`,
  and Windows locks the loaded file. This is true of every binary module.
- The DLL should be signed with the module's certificate when module signing is
  introduced; under WDAC it must be policy-allowed. Constrained Language Mode is
  already unsupported (section 17).
- A bug in the core is a C# bug. The core is small enough for a PowerShell developer
  to read, and it gets xUnit tests next to the Pester tests.

**What this is not.** An earlier internal sketch proposed a full C# engine product
with data stores, collectors and serverless per-test fan-out. This design takes only
the scheduling core. Per-test fan-out for a host is served by `Invoke-MtTest -Id` and
the partition contract in section 13.1.

## 6. Applicability

| Dimension | Vocabulary | Semantics | When omitted | Enforced in 3.0 |
| --- | --- | --- | --- | --- |
| `Service` | service registry names, or `None` | all-of | no requirement (a lint error for built-ins) | yes |
| `CompatibleLicense` | service plan names such as `AAD_PREMIUM`, `INTUNE_A` | any element; `&` inside an element is all-of | no requirement | yes, with a config switch |
| `TenantType` | Workforce, External | any-of | Workforce | detected and recorded; off by default |
| `Cloud` | Commercial, GCC, GCCHigh, DoD, China, Bleu, Delos, GovSG | any-of allow-list | all clouds | detected and recorded; off by default |
| `Platform` | Windows, Linux, MacOS | any-of allow-list | all platforms | yes |

- **Order:** disabled by config, selection, platform, tenant type, cloud, service,
  licence, parameter binding. The first failing gate gives the reason.
- **A failed gate always produces a row.** Config and selection give `NotRun`; a
  parameter-binding failure gives `Error`/`InvalidConfiguration`. Platform, tenant
  type, cloud, service and licence give `Skipped` with the test's `.md` description, a `ReasonCode`
  and a `ReasonDetail`. For service and licence the row also carries the 2.x skip code
  and text, so reports read as they do today. This matches the owner's position on
  PR 1746 that unlicensed tests still appear with their content.
- **Platform** is the running operating system (`$IsWindows`, `$IsLinux`, `$IsMacOS`).
  Most checks are cross-platform and declare nothing. A
  check that calls a Windows-only API or module declares `Platform = 'Windows'` and is
  `Skipped`/`PlatformMismatch` elsewhere. The converter cannot infer this, so built-ins
  start with no value; a lint flags likely Windows-only calls (`Get-WmiObject`,
  `Get-CimInstance` without a session, `Import-Module ActiveDirectory`,
  `#Requires -PSEdition Desktop`, `[System.DirectoryServices.DirectoryEntry]`) for the
  maintainer to confirm. The value is also the partition key a host uses to send
  Windows-only tests to a Windows container (section 13.1).
- **Active Directory** stays as today. It is the only opt-in service in the 3.0
  registry: its 270 checks are `NotRun`/`OptInServiceNotConnected` unless AD is
  connected. Every other unconnected service gives `Skipped`/`ServiceNotConnected`.
- **Services.** Values are validated against the service registry, not a fixed list in
  the class. The registry holds the ten names in use today (Graph, Azure,
  ExchangeOnline, SecurityCompliance, SharePointOnline, Teams, Dataverse, AzureDevOps,
  GitHub, ActiveDirectory), with `EOP` as an alias of SecurityCompliance. The two
  hard-coded lists in `Connect-Maester` and `Test-MtConnection` disagree today; both
  are widened to the union and a unit test keeps them equal to the registry. A custom
  test that names an unregistered service gets a `Skipped` row with reason
  `ServiceNotRegistered`. Packages can register services by namespaced ID later
  without changing the attribute.
- **Licences.** Tokens are Microsoft service plan names with OR/AND, the same grammar
  as ZTA's `Test-ZtLicense` (owner position on PR 1746), compared case-insensitively.
  In 3.0 each token resolves through an engine table to the same ID sets
  `Get-MtLicenseInformation` uses today (service plan IDs, plus the SKU IDs it matches
  for some products, such as the two Microsoft 365 Business Premium SKUs for Exchange
  DLP), so `INTUNE_A` also matches its government and
  education variants and the verdict equals today's in-function guard. A unit test
  asserts that equality against commercial, GCC, EDU and Business Premium SKU fixtures.
  Only SKUs with `capabilityStatus` `Enabled` count, as today. Licence state is
  three-valued; "unknown" never skips a test. A token that is not in the table (a
  custom or ported ZTA test) is matched literally against the tenant's plan names;
  built-ins may only use tokens in the table.
- **Tenant type** comes from `organization.tenantType`: `AAD` is Workforce, `CIAM` is
  External, anything else is Unknown and never gates.
- **Cloud** comes from the Graph endpoint host: `graph.microsoft.com` is `Commercial`
  with source `Assumed`, `graph.microsoft.us` is GCCHigh, `dod-graph.microsoft.us` is
  DoD, `microsoftgraph.chinacloudapi.cn` is China, and the `sovcloud` hosts are Bleu,
  Delos and GovSG. An unknown host is `Unknown`, which never gates. GCC shares the
  worldwide endpoint and cannot be told apart from Commercial through Graph, so a GCC
  tenant states `Environment.Cloud = GCC` in its config.
- **What `Cloud` does not do in 3.0.** It is an applicability fact only.
  `Connect-Maester -Environment` keeps today's values; 3.0 does not add connection
  support for Bleu, Delos or GovSG. The values exist so tests can be classified now.
  Links in results and remediation text are not made cloud-aware either: 86 check
  functions and 235 `.md` files hard-code commercial portal hosts. That can be fixed
  later without a format change.
- **Why tenant type and cloud are not enforced yet:** no existing check has been
  classified for either and there are no test tenants. Shipping the properties, the
  detection and the switch now means classification can happen check by check, and
  turning enforcement on later is a config default change.
- **What stays in the test body:** conditions that cannot be declared, such as "skip if
  another policy exists", tenant-state skips, two inverse-licence cases, and a 401/403
  at run time. Connection and licence guards are removed from built-in functions by
  the migration (section 14) and must not appear in new tests (lint).
- **Swapping in ZTA logic later.** Each fact has one provider function. ZTA's tenant
  type detection is the same call. Its licence check cannot be dropped in unchanged: it
  matches plan names literally, has no government or education equivalents, and treats
  a failed lookup as "no licences". The provider seam is where that is adapted.
- `Test-MtConnection` and `Get-MtLicenseInformation` stay public for custom tests.
  During a run they answer from the tenant context, which removes about 430 repeated
  live probes.

## 7. Selection and run configuration

### 7.1 Selection rules

Preserved from 2.x:

- `-Tag` is any-match, `-ExcludeTag` wins, both case-insensitive.
- Preview tests are excluded unless `-IncludePreview` or any `-Tag` is passed.
- Long-running tests are excluded unless `-IncludeLongRunning` is passed or `-Tag`
  contains `LongRunning` or `CAWhatIf`. Selecting one by another tag, including its ID
  tag, leaves it `NotRun`, as today.
- Deselected tests stay in the result as `NotRun` rows with their description.
- A native test carries its ID as an implicit tag, so `-Tag MT.1068` and
  `-ExcludeTag CIS.M365.3.1.1` keep working.

Fixed, from M2 (M1 keeps the 2.x behaviour):

- `-Tag All` and `-Tag Full` run nothing today, because no test carries those tags. They
  become aliases for the include switches, with a deprecation warning.
- A caller's `PesterConfiguration.Filter.ExcludeTag` is merged with the defaults instead
  of being overwritten.
- A run needs no test folder. Today `Invoke-Maester` fails without `*.Tests.ps1` files.

New:

- `-TestId` / `-ExcludeTestId`: exact IDs and `*` wildcards, case-insensitive. An ID
  named without a wildcard runs even if it is Preview or long-running; a wildcard match
  does not lift either exclusion.
- `NotRun` rows carry a reason code (appendix A.1).
- `Invoke-Maester -DryRun` returns the normal result object after stage 6 without
  executing anything. A test that would have run is `NotRun` with reason `DryRun`;
  every other row is the row a real run would give. A family is one row on its parent
  ID. It is the "what would run and why not" plan.

### 7.2 `-Path` and which built-in tests run

In 3.0 the built-in tests ship in the module, so updating the module updates the tests.
`-Path` becomes "where my custom tests and config live".

- **Built-in tests always run** (owner ruling). `-SkipBuiltIn` (or
  `Selection.BuiltIn = None`) runs custom tests only. The costs, all listed on the
  "Upgrading from 2.x" page: `-Path ./Custom` and `-Path ./tests/Maester/` (both
  documented today) start running every built-in; tests a user disabled by deleting
  wrapper files come back and must be disabled in config instead; and workflows that
  pin an older maester-action with `include_public_tests: false` and
  `maester_version: latest` start running every built-in on the day 3.0.0 is published,
  which is why the action release in section 15.3 precedes 3.0.0.
- **When `-Path` is omitted** the root is the current directory, as in 2.x; 13 of 30
  public call sites rely on that. Because a 3.0 run no longer needs a test folder,
  people will run it from a home directory or an unrelated repository, where a
  recursive scan would execute every unrelated `*.Tests.ps1` inside the Maester module
  with a connected tenant. So with `-Path` omitted, custom tests are scanned for only
  when the directory is recognisably a Maester folder: config discovery finds a user
  config file, or the directory itself contains a `Custom` folder, a 2.x suite folder,
  or a `*.Tests.ps1` or `Test.*.ps1` file. The scan is then recursive, as in 2.x.
  Otherwise built-ins run and one information line says to pass `-Path`.
- **An explicit `-Path`** is always scanned recursively. If it does not exist, that is
  a warning recorded in the result, not an abort: built-ins still run, and config
  discovery starts from the nearest existing parent folder. This keeps the
  documented `Invoke-Maester -Path ./tests/Maester/` producing a report after
  `Update-MaesterTests` has removed the 2.x suite folders. With `-SkipBuiltIn` a
  missing path stays an error.

### 7.3 The run configuration

One document format: a superset of today's `maester-config.json`. Every existing
`maester-config.json`, `Custom/maester-config.json` and `maester-config.<tenantId>.json`
loads without conversion. An empty file is an empty config.

```json
{
  "ConfigVersion": "3.0",
  "Metadata": { "RunId": "0f3c9a", "RequestedBy": "nightly-pipeline" },
  "GlobalSettings": {
    "EmergencyAccessAccounts": [ { "Type": "User", "Id": "6f9619ff-8b86-d011-b42d-00c04fc964ff" } ]
  },
  "Selection": {
    "BuiltIn": "All", "DefaultAction": "Run",
    "Tag": [], "ExcludeTag": [], "TestId": [], "ExcludeTestId": [ "MT.1024.*" ],
    "IncludePreview": false, "IncludeLongRunning": false, "OnUnknownId": "Warn"
  },
  "TestSettings": [
    { "Id": "MT.1005", "Severity": "Critical" },
    { "Id": "MT.1089", "Enabled": false, "Reason": "Not relevant for this tenant" },
    { "Id": "MT.1198", "Parameters": { "MaximumValidityDays": 180 } }
  ],
  "Environment": {
    "TenantType": "Auto", "Cloud": "GCC", "Licenses": "Auto", "Services": "Auto",
    "Enforce": { "Service": true, "License": true, "TenantType": false, "Cloud": false }
  },
  "Execution": { "TestTimeoutSeconds": 0, "LongRunningTimeoutSeconds": 0, "MaxParallel": 1 },
  "Output": { "ErrorsAsFailures": false, "TestResult": { "Format": "NUnitXml", "Path": null } }
}
```

- **How it is supplied.** Exactly one source is used: `-Config <path | object | array>`,
  else `MAESTER_CONFIG` (a path), else the discovered files. `-Config` makes the run
  hermetic: files under `-Path` are not read for config. An array may mix paths and
  objects and is merged left to right, so a run that wants its own file plus a policy
  document supplied by a host passes both.
- **Discovery** uses today's search order (`-Path`, `-Path/tests`, up to five parents).
  Each of the three file kinds is an optional layer. From 3.0.0 the module no longer
  ships a fallback file, so with no file found the defaults apply. A
  `Custom/maester-config.json` with no root file beside it is now honoured; today it is
  ignored, and that is exactly what `Get-MaesterCloudConfig` writes.
- **Layers, lowest to highest** (owner position on issue 1728): defaults (attributes,
  `param()` defaults, the settings registry and, until the last suite migrates, the
  rows still in the module's shipped config for suites not yet migrated); then the one
  config source, which for discovered files is `maester-config.json` plus the `Custom/`
  overlay and then `maester-config.<tenantId>.json`; then explicit parameters.
- **Merge rules.** `GlobalSettings` per key. `TestSettings` per `Id`, per property.
  Other sections per key. Arrays replace, so an empty array in a higher layer clears
  the lower one. On the command line, `-Tag` and `-TestId` replace the config lists;
  `-ExcludeTag` and `-ExcludeTestId` add to them.
- **`TestSettings` rows apply to any test ID**, built-in or custom, native or Pester.
  Keys: `Severity`, `Enabled`, `Reason`, `Parameters`, `TimeoutSeconds`. Today only
  `Severity` is applied, and a row in the `Custom/` overlay works only if the main file
  already has a row for that ID.
- **IDs that match no test** do not fail the run by default. The engine writes one
  summary warning and lists them in the result under `Selection.UnknownIds`.
  `Selection.OnUnknownId` is `Warn` (default), `Ignore` or `Error`; `Error` stops the
  run before selection. An ID under a declared family's parent ID is never reported as
  unknown, whether or not that instance exists in this run. A host that manages
  several report formats or keeps history will send IDs of removed tests on every run.
- **`Selection.DefaultAction`** sets the default for `TestSettings[].Enabled`. With
  `Run`, a test is enabled unless a row disables it. With `Skip` (allow-list mode), a
  test is admitted only if a row for its ID sets `Enabled: true`; a row with only
  `Severity` or `Parameters` does not admit it. A row on a family's parent ID or on any
  of its instance IDs admits the family. Admission is a gate only: tag, Preview and
  long-running rules still apply afterwards. A test that is not admitted is a `NotRun`
  row with reason `NotListed`, so a host sees the new ID without the test having
  executed. This is what "hold new tests until reviewed" needs. `Skip` with no
  `Enabled: true` rows runs nothing, so a host sends `Run` until it has a baseline from
  a first report or from the shipped catalog.
- **Parameters** are validated by the engine against the test's `param()` block before
  the test is called. PowerShell's own binder is too lenient for this: it turns `90.5`
  into `90` and accepts abbreviated names. An invalid value gives that test an `Error`
  row with reason `InvalidConfiguration`; the run continues. Appendix A.5 gives the
  type rules.
- **Settings.** `GlobalSettings` keeps its name. A settings registry in the engine
  records each known setting's type, default and whether it is sensitive. Unknown keys
  pass through, so packs can use `Namespace.Key`. `Get-MtSetting` is exported, with
  `Get-MtMaesterConfigGlobalSetting` as an alias; one public test pack already calls
  that private function.
- **Forced facts.** Each `Environment` value is `Auto` or explicit: a cloud name, a
  tenant type, a list of plan names, or a map of service name to true/false.
- **Execution.** `TestSettings[].TimeoutSeconds` wins over `LongRunningTimeoutSeconds`
  (tests marked `LongRunning`), which wins over `TestTimeoutSeconds`. In 3.0 a
  `MaxParallel` above 1 is accepted and ignored, with one warning.
- **Accepted risk is not an engine feature in 3.0.** It is applied by hosts when
  results are read. The key `Dispositions` and the row field `Disposition` are reserved
  so that an engine overlay can be added later without changing the document shape.

### 7.4 Do we still need `tests/maester-config.json`?

**No, not the shipped file.** Its 700 rows hold only `Id`, `Title` and `Severity`.
`Title` has no runtime effect and `Severity` moves to the attribute. The rows are
deleted suite by suite as each suite migrates, and the file is removed from the repo
and the module when the last suite lands. The five `GlobalSettings` defaults move to
the settings registry.

**Yes, the format and the file name**, as the user's run configuration.

- A `Custom/maester-config.json` keeps working unchanged.
- **A tenant-specific file changes from replace to merge.** Today
  `maester-config.<tenantId>.json` is loaded instead of `maester-config.json`, and
  `Custom/` is applied on top of it. In 3.0 the tenant file is merged over
  `maester-config.json` plus `Custom/`. A tenant therefore inherits base settings it
  does not set itself (for example another tenant's `EmergencyAccessAccounts`), and the
  tenant file wins over `Custom/`. A tenant file that relied on hiding a base value
  must set it explicitly. When the merged result differs from what 2.x would have
  loaded, the engine warns once and names the keys.
- A stale copy of the shipped file in a user's folder keeps acting as 700 severity
  overrides. The engine warns that it looks like a 2.x shipped copy, and
  `Update-MaesterTests` offers to reduce it to the rows that differ from the defaults.
  The 2.x report's Export Config button produces the same kind of file.

### 7.5 What this gives hosted runners and CI

A host that runs Maester on a schedule for many tenants needs, before the run, a
catalog it can build a UI from and, for the run, a way to say exactly which tests run
with which values. 2.x offers neither cleanly: selection is by tag only, config is
anchored on the tests folder, and the catalog can only be learned from a previous run.
In 3.0:

| Need | 3.0 |
| --- | --- |
| Turn a test off for a tenant | `TestSettings[].Enabled = false`; the test is not executed and appears as `NotRun`/`DisabledByConfig` |
| Run only chosen tests | `Selection.TestId`; nothing else executes |
| Hold new tests until reviewed | `Selection.DefaultAction = Skip` plus `Enabled: true` rows for reviewed IDs; unreviewed tests come back as `NotRun`/`NotListed` without executing |
| Supply config without touching the file system | `-Config <object>`, hermetic |
| Know the catalog before any run | `Get-MtTest` and the shipped `Maester.TestCatalog.json`, no tenant needed |
| Classify rows by origin | `Source` and `Suite` on every row; product is still derived from `Block`, which the golden file keeps stable |
| Know the Graph permissions a release needs | the `Get-MtGraphScope` lists are written into the catalog at build time |
| Customise a test per tenant | `TestSettings[].Parameters`, with the catalog's parameter kinds driving the host's pickers (section 3.4) |
| Tolerate IDs the engine does not know | `Selection.UnknownIds` and `OnUnknownId` |

What stays with the host: multi-tenant resolution, review workflows, accepted-risk
storage, schedules, access control, and any filtering it applies when it stores
results. A disabled test is still a `NotRun` row in the raw JSON and HTML, so "turned
off means no result" remains a host-side rule.

Two things a host must handle when it moves to 3.0 run configs:

- **Family parent rows.** A row on a family's parent ID (section 10) is an ID a host
  keyed on 2.x instance rows has never seen. Policy and drift should key on `ParentId`
  when present.
- **Token refresh.** A host that refreshes an app-only token mid-run by shadowing
  `Invoke-MgGraphRequest` in the session keeps working in single-threaded 3.0; it will
  not survive worker runspaces, so a host-facing refresh hook is part of the parallel
  work.

## 8. Backward compatibility for Pester tests

- **Real Pester, not a re-implementation.** Custom tests in public repos use
  `BeforeAll`, `BeforeDiscovery`, `-ForEach`, `-Skip:(expr)`, `Context`, `Set-ItResult`
  and many `Should` operators. The provider calls `Invoke-Pester` once, from a module
  function, after the native tests. It keeps the 2.x result mapping for those rows.
- **Selection by ID for Pester tests.** The ID is the text before the first colon of
  the `It` name. Only 43% of public custom tests also carry their ID as a tag, so tags
  cannot be the mechanism. The engine scans the files statically, then appends
  `Filter.ExcludeLine` entries for deselected tests. Excluded tests stay as `NotRun`
  rows and `-Skip` is respected. A test whose ID is built at run time is selectable as
  a family only; if it executes although deselected, it is reported `NotRun` with
  reason `DeselectedAtRuntime` and listed in one warning.
- **Stale copies of 2.x built-in wrappers.** A Pester test outside a `Custom` folder is
  superseded when its ID is a built-in ID, **a previous ID of a built-in**, or the ID
  of a built-in that was since removed. It is not executed and produces no row; one
  warning names the files and suggests `Update-MaesterTests`. `-SkipBuiltIn` runs
  custom tests only; superseded copies are still not run.
  - Older copies carry IDs that were later renamed: CISA checks were `MS.AAD.7.1`
    before the `CISA.` prefix, and early CIS and Teams wrappers have no colon. In the
    public sample 13% of stale `It` blocks have such an ID. Without a previous-ID
    table those checks would run twice, under two IDs.
  - The table (`Maester.LegacyIds.json`) maps every historical ID to its current ID or
    to `retired`. It is generated once from the git history of `tests/` and ships as
    frozen data.
  - A stale copy of a family wrapper has no static ID. It is superseded when the
    literal start of its `It` name begins with a built-in family's parent ID and a dot
    (`MT.1024.`, `MT.1033.`, `MT.1034.`, `MT.1059.`, `MT1060.`).
  - Matching on the function a wrapper calls is rejected: it would silently supersede
    genuine custom tests that wrap a built-in function.
- **No override by folder.** A Pester test with a built-in ID is superseded wherever it
  sits, including under `Custom/`. `tests/Custom/README.md` tells 2.x users to copy and
  modify built-in tests there; that advice is withdrawn. To customise a built-in, set
  its parameters in config, or copy the native test under a new ID and disable the
  built-in.
- **ID collisions for native tests.** A result never has two native rows with one ID. A custom
  native test with a built-in ID is not loaded and the built-in runs; to customise a
  built-in natively, set its parameters in config, or copy it under a new ID and
  disable the built-in. Two custom native tests with the same ID, or a custom native
  test and a custom Pester test with the same ID, give one `Error` row with reason
  `DuplicateId` and neither runs. Pester rows that repeat an ID among themselves are
  all kept, as in 2.x, and listed in one warning.
- **Calling a built-in function directly from a custom Pester test is not supported
  in 3.0.** The functions still exist in module scope, but the migration removes their
  connection and licence guards and their outer `try`/`catch`, so a direct call on a
  tenant without the service gives an exception instead of a skip. The supported form
  is `Invoke-MtTest -Id MT.1005`, which runs the check through the engine with its
  gates and returns the row. Public evidence: 8 of 367 custom `It` blocks call a
  built-in directly, 4 of them `Test-MtConditionalAccessWhatIf`, which stays exported
  because it is a documented user cmdlet. This is listed in "Upgrading from 2.x".
- **`BeforeDiscovery`, `BeforeAll`, `-ForEach`, `-Skip:(expr)`, `Context`,
  `Set-ItResult`** work exactly as today, because the provider is real Pester. A
  `BeforeDiscovery` block runs during Pester's discovery, after `Connect-Maester`, so
  it can call Graph as it does now. The only limit is selection: a test whose name is
  built at discovery time can be selected or disabled as a family, not per instance.
  Built-in tests that used these constructs map to native ones (section 14).
- **`-PesterConfiguration` stays; its type becomes `[object]`** so the parameter binds
  when Pester is not loaded. It accepts a `PesterConfiguration` or a hashtable. The
  engine reads the keys that also make sense for native tests (`Run.Path`,
  `Filter.Tag`, `Filter.ExcludeTag`, `TestResult.*`, `Output.Verbosity`) and passes
  the rest to the Pester provider. Appendix A.3 gives the mapping. Without it, a
  caller who filters only through this object would get every built-in.
- **Pester versions.** Supported: 5.7.1 and later, including 6.x. On 5.7.1 and 6.0.0
  the pieces Maester relies on behave the same, given two settings the provider forces where the
  option exists (both are Pester 6 only):
  `Run.Parallel` off (Pester 6 would run tests outside the module and lose every result
  detail) and `Run.FailOnNullOrEmptyForEach = $false` (Pester 6 otherwise fails
  discovery of any file with an empty `-ForEach`). Three Pester 6 differences are
  documented for custom-test authors: `-Tag None` is reserved, `Set-ItResult -Pending`
  is removed, and non-string values in `<...>` name templates render differently.
- **Pester is no longer a dependency.** It leaves `#Requires` and `RequiredModules` and
  is imported (`-MinimumVersion 5.7.1`, so the Pester 3.4 that ships with Windows
  PowerShell is never loaded) only when the plan contains Pester files. If it does and
  no suitable Pester is installed, those tests become `Error` rows with reason
  `PesterNotAvailable` and an install hint, and the native results are still produced.
  Consequences handled elsewhere: maester-action and the CI samples call
  `New-PesterConfiguration` before `Invoke-Maester`, so they get a release that
  installs Pester explicitly as its own step before 3.0.0 (section 15.3);
  `Install-MaesterTests` stops installing Pester; the upgrade guide tells users with
  Pester-format tests to install it.
- **NUnit/JUnit XML.** Today Pester writes it. From M3 Maester writes one merged
  NUnit 2.5 or JUnit 4 file covering native and Pester rows,
  requested through the config or through a caller's `PesterConfiguration.TestResult`
  as today. Appendix A.2 gives the outcome mapping that keeps Azure DevOps pipelines
  failing on what they fail on today.

## 9. Result contract

- Every 2.x top-level and per-test field is kept with the same name. `Result` is
  exactly one of `Passed`, `Failed`, `Error`, `Investigate`, `Skipped`, `NotRun`. No
  seventh value: existing consumers reject or misfile anything else.
- **Invariants.** One `*.json` per run in the output folder. No top-level
  `TestResultSummary`. `MaesterConfig` and `InvokeCommand` are always present.
  `Tests[].Id` is unique case-insensitively among native rows.
- For native rows: `Name` is `<Id>: <Title>`, `Block` is `Category`, `ScriptBlock` is
  empty, `ScriptBlockFile` is the repository-relative source path for a built-in and
  the full path for a custom test, `Duration` has millisecond precision.
  The top-level `Blocks` array has one entry per category. `PesterConfig` and the Pester
  durations are present and empty when Pester did not run.
- Additive, top level: `SchemaVersion` (`2.1`, meaning "2.x shape plus additions"),
  `CatalogVersion`, `TenantContext`, `RunMetadata` (the config's `Metadata`, echoed),
  and `Selection` (`BuiltIn`, `UnknownIds`, `Superseded`).
- Additive, per test: `Source`, `Suite`, `Format` (`Native` or `Pester`), `ReasonCode`,
  `ReasonDetail`, `ParentId`, `InstanceId`, `Parameters` (effective values, their
  source and resolved display names), `Diagnostics`. Reserved: `Disposition`,
  `Package`.
- **Reason codes are a closed list** (appendix A.1). "Not applicable" is a reason code
  on a `Skipped` row, not a new status. Every row the engine produces without running
  the test also fills the 2.x text fields, so older readers show the reason.
- **`MaesterConfig`** is the effective run config. Its `TestSettings` is synthesised as
  one row per test in the run (`Id`, `Title`, effective `Severity`, `DefaultSeverity`
  from the attribute, and any user keys), from M3 on. This keeps the report's Config
  page populated after the shipped rows are deleted. `ConfigSource` stays a string and
  names every layer that contributed, lowest first, or `-Config`. Sensitive settings are redacted; keys that are not in the
  settings registry are echoed by name with the value replaced.
- A JSON schema for the result ships in the module and generates the report app's
  typed model. The report gains a reason column, a native/Pester badge and a
  run-configuration section. Its Config page shows defaults plus overrides and exports
  only the overrides.
- The marketplace draft's larger envelope (catalog, coverage, provenance) is left for
  that work; `SchemaVersion 3.0` is reserved for it.

## 10. Tests that produce several results

Five families build their IDs at run time today: MT.1024 (one row per Entra
recommendation), MT.1033 and MT.1034 (per user), MT.1059 (per MDI health issue) and
MT1060 (per drift folder). Four of the five, and six other wrapper files, call the
tenant during Pester discovery even in runs that filter them out. Static discovery
removes roughly 9 seconds per run (derived from discovery durations, not measured
directly).

- A family declares `InstanceSource = '<function in the same file>'`. The engine calls
  it in the execute stage and runs the test once per instance.
- **The instance object.** The source returns one object per instance: `Id` (the
  suffix; required, unique within the family, `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`), and
  optional `Title`, `Severity`, `Tag` and `Data`. The test receives it as `$Instance`.
  Title and severity are bound when the family is expanded, so `Error` and `NotRun`
  instance rows keep them. This is how MT.1024 (severity from the recommendation's
  priority) and MT.1059 keep their 2.x rows. A suffix outside the pattern, or a
  repeated one, gives one `Error` row on the parent ID with reason `InvalidInstanceId`.
  The 64-character limit applies to the parent ID only.
- The catalog holds one entry per family, with an `IdPattern`. Rows carry
  `Id = <Parent>.<suffix>`, plus `ParentId` and `InstanceId`.
- **ID matching for families** applies only to declared families, never to ID prefixes
  in general (`ORCA.108` and `ORCA.108.1` are unrelated static IDs):
  - The parent ID or `MT.1024.*` addresses the whole family at plan time, with no
    tenant call.
  - An include that names one instance selects the family; only matching instances are
    invoked, and the others get `NotRun`/`NotSelected` rows on their instance IDs.
  - An exclude or `Enabled: false` on one instance is applied after expansion.
  - `TestSettings` rows resolve on the instance ID first, then the parent ID.
- When a family is deselected, gated, empty or fails, the result holds one row on the
  parent ID. 2.x emits one `NotRun` row per instance when filtered and no row at all
  when empty.
- All five families convert in the last migration milestone, so no built-in Pester
  file ships at 3.0.0 and Pester is needed only for custom Pester tests. A family whose
  parity cannot be shown on a tenant by the release candidate ships marked `Preview`
  until it is, rather than as a Pester file.
- **MT1060 (drift)** becomes a native family whose instance source lists the drift
  folders. Its instance IDs change from `MT1060.<folder>.<n>` to `MT.1060.<folder>.<n>`
  with the folder name sanitised to the instance grammar; it has no observed usage in
  the available result files, and the rename is listed in the release notes.

## 11. Authorship

- `Author` and `Contributor` are arrays of GitHub handles. Profile data stays in
  `website/contributors/contributors.yml`.
- **Credit must be frozen into the attributes before the files move.** A realistic
  single-commit migration exceeds git's rename limit and yields zero detected renames,
  which would make the migrator the author of every test.
- A seed file with author and contributors for all 750 checks has been computed
  (appendix B). It reproduces today's published attribution exactly, so the
  comparisons rest on a validated baseline. The author is the earliest commit on the
  function file with today's overrides applied; it is never filtered by commit size,
  because 71% of checks were created in large pull requests. The seed also fills the
  51 checks that have no attribution today and corrects four checks git gets wrong,
  which the owner has accepted: MT.1038 to Cloud-Architekt, CISA.MS.AAD.2.1 and 2.3 to
  soulemike, MT.1021 to f-bader.
- **Recommended rule for `Contributor`:** at least 5 changed lines, in a commit that
  touches at most 20 files, excluding bots and maintenance commits. Today's rule
  credits anyone who ever touched the file: 1,886 credits, 61% of them to three
  maintainers through bulk commits. The recommended rule gives about 270. Fourteen
  people lose all per-test credit under it; the rule is applied unless the owner
  objects (section 16).
- After the migration the attribute is maintained by hand. A non-blocking PR check
  suggests adding the PR author as a contributor when the same rule is met; measured
  load is 4 to 5 PRs a month. There is no build-time git top-up.
- Upstream credit (EIDSCA, ORCA, CISA ScubaGear, CIS) lives once in `suite.json`. The
  EIDSCA and ORCA generators emit `Author` so regeneration does not erase it.
- `attribution-overrides.yml` and the per-test half of `contributors.mjs` are deleted.

## 12. Public commands, custom tests and packages

- **Stay exported, same signatures (58):** the 56 non-`Test-*` commands plus
  `Test-MtConnection` and `Test-MtConditionalAccessWhatIf`.
- **No longer exported from 3.0.0 (681):** the other `Test-*` functions, including the
  `Test-MtEidscaControl` dispatcher. They stay defined in the module under the same
  names. No shims. Until the cut-over milestone the build keeps exporting migrated
  check functions, so the list is cut once.
- **New:**
  - `Invoke-MtTest [-Id <string[]>] [-Path <file|folder>] [-Parameter <hashtable>]`
    runs one or more checks and returns rows. At least one of `-Id` and `-Path` is
    required; `-Path` alone runs every native test in the file or folder. `-Parameter`
    is allowed only when exactly one test is selected. This replaces calling `Test-Mt*`
    directly and is the author's development loop.
  - `Get-MtTest [-Id] [-Tag] [-Path]` returns the catalog as objects without a tenant
    connection. With `-Path` it validates a file or folder and returns errors with file
    and line.
  - `New-MtTest` scaffolds the two files.
  - `Convert-MtTest -Path <folder> [-WhatIf]` converts a user's Pester-format tests to
    the native format (section 12.1).
  - `Get-MtSetting`, `Get-MtTenantContext`.
- `Invoke-Maester` gains `-Config`, `-TestId`, `-ExcludeTestId`, `-DryRun` and
  `-SkipBuiltIn`. All existing parameters stay.
- `Get-MtTestInventory` stays for one major version as a wrapper over `Get-MtTest`.
- **`Install-MaesterTests`** keeps its name. It writes `Custom/README.md` and a short
  `maester-config.json` template. It never writes a file that discovery treats as a
  test, because existing pipelines (maester-action by default) call it on every run and
  then point `-Path` at that folder. It no longer installs or checks Pester.
- **`Update-MaesterTests`** removes 2.x wrapper files whose every ID is a current,
  previous or retired built-in ID, never touches `Custom/`, and supports `-WhatIf`.
- **The `maester365/maester-tests` repository** keeps its 2.x content on `main` until
  3.0 has been out for a release cycle, because pipelines clone it at run time and pass
  `-Path ./tests/Maester`.
- **An older Maester installed side by side.** `Update-Module` keeps 2.x installed.
  Once check functions are no longer exported, any call to one from outside the module
  (the prompt, a script, a plain `Invoke-Pester`) makes PowerShell auto-load the 2.x
  module and run 2.x code, and from then on the session's `Invoke-Maester` is the 2.x
  one. So on import and at the start of a run, 3.0 checks for an installed version
  below 3.0 and writes one warning with the exact uninstall command. During a run it
  checks for a second Maester instance after each native test and after the Pester
  call. A native row during which one appeared is `Error` with reason
  `ForeignModuleLoaded`; for the Pester call the result carries one run-level warning.
  The engine then removes the foreign module, which restores command resolution to
  3.0, before it continues.

### 12.1 Custom tests

Section 3.7 describes the authoring side. The compatibility side: Pester-format custom
tests keep running (section 8), and 3.0 ships a converter (owner ruling), as the RFC
promised:

- `Convert-MtTest -Path <folder> [-OutputPath] [-WhatIf]` shares the AST core of the
  build converter in section 14. It handles, without user edits: the documented
  split-file pattern (function `.ps1` + `.md` + thin `.Tests.ps1`, used by 86 of 243
  public custom files), and any `It` whose body is one call to a function defined in
  the same folder with a boolean `Should`. It writes `Test.<ID>.ps1` + `Test.<ID>.md`,
  carries the `It` name, tags and `Severity:` tag into the attribute, turns a leading
  `Test-MtConnection` guard into `Service`, drops the outer `-SkippedBecause Error`
  `catch`, and generates a `.md` from `-Description` or the function's help when there
  is none.
- An `It` with inline logic is converted to a function whose body is the `It` body,
  with a trailing `... | Should -Be $true` rewritten to `return`; other assertions,
  `-ForEach`, `BeforeDiscovery` data and `Set-ItResult` are left in place with a `TODO`
  comment and listed in the report. The original Pester file is kept until the user
  deletes it; a converted file and its source cannot both run, because the engine
  supersedes the Pester test by ID.
- The converter never runs test code: it works from the AST, like discovery.
- IDs are kept as written. An ID without a prefix (`CT0001`) still converts; the
  report suggests a prefix.

### 12.2 Packages and the marketplace

The marketplace is a later release, but its package model is fixed now so that 3.0
tests and 3.0 engine seams are already the package format. It follows the earlier
marketplace draft and the skills.sh idea of publisher-owned Git repositories with a
central index.

- **A package is a Git repository** holding native tests plus one manifest:

  ```text
  maester-package.json
  tests/
    Test.CONTOSO.1001.ps1
    Test.CONTOSO.1001.md
  ```

  The manifest is `suite.json` with package fields: `Id` (`<publisher>.<package>`),
  `Version`, `Publisher`, `RequiresMaester`, `License`, `SupportUrl`, the tests folder,
  and later `Services`, `ParameterKinds` and `Permissions` it contributes. Test IDs are
  namespaced by the publisher's prefix and must not collide with built-ins.
- **Installing** (`Install-MtPackage <id | owner/repo> [-Version]`): resolve a tag to
  a commit, download the archive without running anything in it, validate it
  statically (attributes, `.md` pairing, no top-level statements, ID namespace, a
  secrets scan), show publisher, commit, digest, capabilities and requested
  permissions, require approval, copy the immutable snapshot to the package store
  (`~/.maester/packages/<id>/<version>`), and write `maester-packages.lock.json` with
  source, commit and digest. `Get-`, `Update-`, `Uninstall-` and `Find-MtPackage`
  complete the set; `Find-` queries a public registry repository where publishers list
  packages by pull request and automation verifies repository control, manifest and
  scans. Direct install from any repository stays possible without a listing.
- **Running:** an installed package is loaded the way a custom folder is (section 5.1):
  one private module per package, namespaced IDs, `Source = Custom` until consumers
  understand packages, and the reserved `Package` field on each row. A run uses
  the locked snapshot, never the repository's current branch.
- **Trust:** running downloaded PowerShell with Graph and Exchange credentials is a
  supply-chain boundary. In-process execution is an explicit trust decision at
  install; a child-process host for connection providers and collectors, and a
  separate marketplace result envelope (`SchemaVersion 3.0`), are later phases of the
  draft and need nothing from 3.0 beyond what is listed next.
- **What 3.0 ships so that this is additive:** the two-file format and static
  discovery; the private-module loader; `RequiresMaester`; the reserved `Package`
  field; the service registry and parameter-kind registry as the extension points;
  `Source` on every row; and the catalog, which a registry can build a listing from
  without executing anything.

## 13. Parallel-readiness rules adopted now

3.0 runs tests one at a time. These rules are enforced by lint or by the engine for
every native test written from the first preview on, so that a parallel scheduler
later is an engine change:

1. Metadata is static; discovery happens on the main thread.
2. A test gets its identity and inputs from the engine, not from globals.
3. A test reports only through its return value and `Add-MtTestResultDetail`.
4. Results are stored by test ID in an engine-owned store.
5. Tests do not write `$script:`, `$global:` or `$env:` state and do not assign to
   `$__MtSession`.
6. Caches are reached only through helpers, and a helper must not hand out the cached
   object itself.
7. `Service` is the scheduling input. Only Graph REST tests can go to workers. Every
   other service in the registry is marked runspace-bound and stays on one lane until
   cross-runspace use is verified. The plan already records each test's lane.
8. `Exclusive` marks a test that must run alone.
9. No test calls another test.
10. The tenant context and config are immutable.
11. The engine owns progress and console output.

**Lane defaults.** A test goes to a worker only if it is a built-in whose services are
all shareable. Custom native tests, tests with no `Service`, and the Pester provider
stay on the main lane when parallel execution ships. Lint does not run on custom tests,
so a custom test proven on single-threaded 3.0 must not break in a worker later. A
package will be able to opt in with a manifest flag.

What is known about the sessions: Graph and Az keep one process-wide context, so a
worker runspace that has the module loaded uses the main runspace's sign-in (ZTA
relies on this; the spike confirmed a process-wide singleton is visible from pool
runspaces). Exchange Online and Security & Compliance proxy cmdlets exist only in the
session state that ran `Connect-ExchangeOnline`; Microsoft's own guidance for parallel
use is to connect in every runspace, which is possible with app-only certificate
authentication but not with an interactive sign-in. PnP uses an explicit connection
object. Teams is undocumented. So the first parallel release keeps those services on
the main lane, with per-worker Exchange sessions for app-only runs as a later option,
and process-level partitions (section 13.1) as the alternative that needs no shared
session at all.

**Baseline in migrated tests**, exempted by ID and cleared before 3.0.0:

- The 67 generated ORCA functions assign `$__MtSession.OrcaCache` directly; the
  generator template is changed to call a helper.
- Three test-to-test calls move to shared helpers (one by hand, two in the EIDSCA
  template).
- Six CISA mail checks modify a cached DNS record; fixed in the helper.

What to expect later, from the timing data: in a scheduling simulation over eight
Graph-only runs, seven (196 to 292 seconds of test time) drop to 49 to 73 seconds with
four workers; one (407 seconds) drops only to 177 because a single test took 177.
These are upper bounds that ignore Graph throttling. Exchange-connected runs gain only
1.1 to 2.6 times until the ORCA and Exchange work is restructured, because those tests
share one session.

### 13.1 Running partitions in other containers

Not needed today, but the design leaves room for a host to split one run across
containers (a Windows container for Windows-only tests, a separate container for
Azure tests, several containers for Graph tests) and consolidate the results. It
rests on four things 3.0 already has, plus one small addition:

- **The plan is data.** After stage 6 the engine holds a list of work items with `Id`,
  `Suite`, `Service`, `Platform`, `Lane` and `Exclusive`. `Invoke-Maester -DryRun`
  returns it. A host groups it by any key it likes.
- **A partition is an ordinary run.** Each container runs
  `Invoke-Maester -Config <doc> -TestId <ids>` with the same `Metadata.RunId`, the same
  `Environment` values forced (so every container reaches the same applicability
  conclusions), and the same module version. Each container connects itself; sessions
  are never shared across processes. Only the catalog version needs to match, and the
  merge checks it.
- **Consolidation.** `Merge-MtMaesterResult` gains a same-run mode: it unions the rows
  of several partial results by ID, recomputes the counts and blocks, keeps each
  container's `TenantContext` under a `Partitions` array, and synthesises
  `NotRun`/`NotSelected` rows from the catalog for anything no partition covered, so
  the merged report shows the whole catalog. This is the one addition, and it is small.
- **Process-level parallelism** is also the cheap answer for runspace-bound services:
  Exchange tests in one process and Graph tests in another need no shared sessions.
  The same partition and merge contract serves a local host that starts child `pwsh`
  processes and a hosted runner that starts containers.
- **What the engine could add later:** `Execution.Partition` with a key and a host hook
  that launches partitions, and a `-Partition <key>=<value>` parameter that selects a
  partition from a plan file instead of listing IDs.

## 14. Migration

**Tooling.** An AST-based converter (`build/migration/Convert-MtPesterTest.ps1`) driven
by the ID-to-function map, the authorship seed, the tag golden file and the config. For
each check it writes the attribute, moves the function file and `.md` to
`Test.<ID>.*`, appends the Markdown footer where missing, deletes the wrapper `It` and
the config row, and writes a migration report. Counts must reconcile: `It` blocks in
equals tests out plus flagged items. It is a build tool for built-in checks only; it is
not shipped and does not convert custom tests (section 16).

**Function bodies are edited mechanically, and only in listed ways.** The converter
strips two kinds of boilerplate from every built-in function, and the parity harness
proves that the engine produces the same rows without them:

- **Connection and licence guards** at the top of the function, where they match the
  canonical shapes (`if (-not (Test-MtConnection X)) { Add-MtTestResultDetail
  -SkippedBecause NotConnectedX; return $null }` and the `Get-MtLicenseInformation`
  comparisons). 289 functions have only canonical guards and 233 AD functions use the
  collector-null pattern, which is kept because it also guards against empty data; 10
  use the P2-or-Governance two-step; 8 are irregular and are converted by hand. The
  engine's `Service` and `CompatibleLicense` gates replace them.
- **The outer `try`/`catch`** whose `catch` is exactly
  `Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_; return $null`
  (with or without a `Write-Verbose`). The body of the `try` is dedented in place.
  Any `catch` that does anything else is kept.

Both edits are regenerated from a template for ORCA and EIDSCA. Every other change is
one of these exceptions, each recorded in the migration report:

- **Inverted polarity.** 17 wrappers assert `Should -Be $false` because the function
  returns `$true` when the tenant is bad. The 2.x-named function keeps its return
  value, so custom wrappers written against it stay correct. For MT.1049 and eight
  AZDO checks it moves to `powershell/internal/` and a thin `Test.<ID>.ps1` with a new
  function name negates it; MT.1025 to MT.1028 negate in their thin files; four more
  are in the manual tier.
- **Non-boolean returns.** `Test-MtEidsca<ID>` and `Test-MtEidscaControl` keep
  returning the tenant value, and the generated `[MaesterTest]` function does the
  comparison. MT.1022, MT.1023 and MT.1045 compare in thin files for the same reason.
- **`$null` as not applicable.** The 13 functions in section 5.3.
- **The ORCA `return = $null` typo**, fixed in the template.
- **The multi-ID splits** (section 3.1) and the **parallel-readiness baseline**
  (section 13).

**Parity harness.** It runs the same tenant through the old and new paths and diffs
`Result`, `Severity`, `Title`, `Name`, `Block`, `HelpUrl`, tags and skip reason, with
the allow-list in section 5.3. Tenant parity runs do not exercise error paths or
polarity, so both get unit fixtures with mocked data.

**Direct callers lose their safety net.** Once the guards and the outer `catch` are
gone, calling a built-in function directly from a Pester `It` on a tenant without the
service gives an exception instead of a `Skipped` row. That is why direct calls are
unsupported in 3.0 and `Invoke-MtTest -Id` is the replacement (section 8). New tests
must not contain guards or the generic `catch` (lint).

**How 2.x constructs map to 3.0.** This is what the converter does for built-ins and
what the migration guide tells custom-test authors:

| 2.x | 3.0 |
| --- | --- |
| `Describe`/`It` name and tags | `[MaesterTest]` `Id`, `Title`, `Category`, `Tag` |
| `maester-config.json` row | `[MaesterTest]` `Severity` |
| `-Because` sentence | dropped (it only reached Pester's error record) |
| `BeforeDiscovery` that fetches data for `-ForEach` | `InstanceSource` function in the same file |
| `BeforeDiscovery` that checks a licence or connection for `-Skip:` | `CompatibleLicense` / `Service` |
| `BeforeAll` that dot-sources the function file | nothing: the function is the test file |
| `-TestCases` passing discovery data into the body | function parameters, or `$Instance.Data` |
| `Test-MtConnection` / licence guard in the function | `Service` / `CompatibleLicense` |
| outer `try { } catch { -SkippedBecause Error }` | removed; the engine catches |
| `Should -Be $true` | `return $true` |
| `Should -Be $false`, `Should -Be <value>` | the comparison in the test function |
| `$null` meaning not applicable | `-SkippedBecause NotApplicable` |
| wrapper arguments selecting a variant | thin `Test.<ID>.ps1` per variant calling a shared helper |

**Order.** Pilot of about 10 mixed checks, then cis (49), cisa (79, plus one flagged
orphan), ad (270), Maester + XSPM + AZDO (about 240), then ORCA (67) and EIDSCA (44) by
changing their generator templates, then the manual residue and the families.

| Tier | `It` blocks |
| --- | --- |
| Fully scriptable (including the guard and `catch` removal) | 564 |
| Scriptable with a simple rule (25 wrapper skips that become declarations, 20 shared-function thin files, 9 inverted assertions) | 54 |
| Regenerate from templates (ORCA, EIDSCA) | 111 |
| Manual (the five families, inline wrappers, 8 irregular guard shapes) | 21 |

**Data clean-up decided by the design:**

- The wrapper title wins over the config title; the config severity wins.
- The 52 static checks with no severity from any source get a maintainer-reviewed
  value in a 2.x PR before their suite migrates. MT.1182 computes its severity at run
  time and keeps doing so.
- 64 checks with no `.md` get one generated from the function's description and
  flagged for review.
- Orphan `.md` files and stale config IDs are deleted.
- The never-discovered wrapper `tests/cisa/exchange/Test-MtCisaDmarcReport.ps1` is not
  activated by the migration. Its function is rewritten as the new native check
  `CISA.MS.EXO.4.4`, following the ScubaGear rule (an agency `rua` address besides CISA's
  and a `ruf` address); the golden test lists it as new in 3.0.
- The `-Because` sentences in wrappers are dropped: they only reach users through
  Pester's error record, which the HTML report strips.

**Generators.** The EIDSCA and ORCA generators are rewritten to emit native files and
run in CI with a drift check. Neither runs in CI today and both outputs have drifted.

**Commits.** Per suite, not squashed, with renames separate from content edits.

## 15. Documentation, build and delivery

### 15.1 Documentation

- **Generated from the catalog:** the test pages (which fixes the 46 AZDO checks that
  have no page today), an attribute reference, a run-config reference, and the
  contributors pages. Test page URLs (`/docs/tests/<ID>`) do not change.
- **Command reference:** generated from real exports only. About 795 of 853 command
  pages are removed: 731 `Test-*` pages and 64 pages for internal helpers that are
  documented by accident today. Check pages redirect to `/docs/tests/<ID>`; helper
  pages redirect to the command index. The 681 `.LINK` lines and 21 sibling Markdown
  links are rewritten in the same change, because the site builds with
  `onBrokenLinks: throw`.
- **2.x docs are kept.** Three things would remove or break the last 2.x snapshot and
  all are fixed before the command pages go: the release script deletes every older
  docs version; the command-reference sync deletes versioned pages that are no longer
  in the source set; and 403 pages in the snapshot link to command pages with absolute
  paths, so the generator emits version-relative links in the final 2.x release.
- **Rewritten by hand:** writing tests (3 pages), configuration (3 pages), installation,
  updating tests, contributing, the 11 monitoring guides, intro, FAQ, the multi-tenant
  pipeline guide, and four READMEs (root, `tests`, `tests/Custom`, `powershell`).
- **New pages:** "Upgrading from 2.x" (every item in section 5.3, the `-Path` rules,
  uninstalling 2.x, direct `Test-Mt*` calls replaced by `Invoke-MtTest`),
  "Migrating custom Pester tests to the native format", "Pester-format tests (still
  supported)", "Applicability", "Result schema and reason codes".
- **Contributor tooling:** `.github/skills/maester-test-expert/SKILL.md` (832 lines
  teaching the four-file model), the nine agent files, `AGENTS.md`, `CONTRIBUTING`,
  `CODEOWNERS`, the PR template.
- **ID reservation** on issue 697 is replaced by `New-MtTest` and a duplicate-ID test
  that runs against the merge result. Two open PRs can add the same ID in different
  folders without a git conflict, so the check must run on the merged tree.

### 15.2 Build and tests

- **Build.** A catalog phase reads the attributes from the AST, validates them, and
  writes `Maester.TestCatalog.json` (appendix A.4). The build fails on a schema error,
  a duplicate ID, a duplicate function name, a missing `.md` or an unknown licence
  token in a built-in. The Markdown bundle is keyed by ID with a function-name index,
  so Pester-mode lookups keep resolving. Native test files are concatenated after
  `public/`. The module no longer ships a `maester-tests/` folder; during the previews,
  built-in Pester files of unmigrated suites ship in `builtin-pester/`, which is empty
  at 3.0.0.
- **Engine DLL.** `src/Maester.Engine/` (C# project) builds to `powershell/lib/
  Maester.Engine.dll`, committed, 40 KB, deterministic. CI rebuilds it on every change
  under `src/` and fails on a byte difference; a load-and-run smoke test runs on
  Windows, Linux and macOS. xUnit tests for the scheduler live next to the
  project.
- **Source import.** The dev `Maester.psm1` also loads `tests/**/Test.*.ps1` and the
  committed DLL, so a contributor who does not touch the engine needs no dotnet SDK.
- **New unit tests:** attribute schema; tag and `Block` golden files; result contract,
  including the fields and values existing consumers depend on and a golden file of
  built-in ID to `Source`; run config with layout fixtures (Custom-only folder, tenant-only,
  root + Custom + tenant, empty); licence-gate equivalence; XML schema validation and
  outcome parity; error-path fixtures; polarity fixtures; selection fixtures
  (`-Tag LongRunning`, `-Tag CAWhatIf`, the `Invoke-Maester` help example that filters
  through `PesterConfiguration` only); stream fixtures; a frozen folder of legacy
  Pester fixtures including the 2024 wrapper shapes and direct calls with a service
  disconnected; generator drift.
- **Existing gates that change**, each in the milestone that breaks it:
  - The 20 or so `powershell/tests/functions/Test-Mt*.Tests.ps1` files that call a
    check function from test scope move to `InModuleScope` or `Invoke-MtTest`.
  - `build/Test-MaesterModuleOutput.ps1`: the 200-command minimum, the expected module
    items and the function-name probe.
  - `build/Update-MaesterConfigVersion.ps1` and its step in four publish workflows are
    removed with the shipped config file.
  - `MaesterConfig.Tests.ps1` and `MaesterTestTags.Tests.ps1` are retired;
    `PesterVersionPinning.Tests.ps1` asserts the new matrix.
  - PSScriptAnalyzer and the Graph-endpoint tests gain the `tests/` root.
  - `Help.Tests.ps1` and `Common.Tests.ps1` iterate exported commands, so about 4,100
    help assertions on check functions disappear. Comment-based help is no longer
    required on native tests; the attribute and `.md` replace it.
  - Publish workflows. `publish-tests.yaml` copies `tests/` to `maester365/maester-tests`
    on every release; from M2 it runs only from `release/2.x`, so that repository keeps
    its 2.x content. `publish-module-preview.yaml` gains `tests/**` in its path filter,
    because native tests are module source.
- **Runtime matrix:** PowerShell 7.4 and 7.6 on three operating systems; Pester 5.7.1,
  5.9.x (what GitHub-hosted runners ship) and the latest 6.x; one job with Pester not
  installed, which asserts a default run produces no `Error` rows and never imports
  Pester. The "Run Tests using Windows PowerShell" CI step is removed (owner ruling:
  PowerShell 7 only), which saves about 14 minutes per pull request.

### 15.3 Milestones

M1 is the last change that may ship as a 2.x minor. A 2.x minor must not change which
tests run, which config value wins, or the XML output for an existing command line.
A `release/2.x` branch is cut at M1 and takes fixes. The module version on `main` is
raised to 3.0.0 before M2 merges, because every push to `main` publishes a prerelease;
from M2 on those prereleases are the 3.0 previews.

| # | Milestone | Gate |
| --- | --- | --- |
| M0 | Contracts and safety net: owner rulings; schema table; golden fixtures for tags, `Block`, results, config layouts and selection; legacy-Pester and error-path fixtures; parity differ; previous-ID table; the C# project, its CI build and its load test on Windows and Linux; manifest raised to PowerShell 7.4 / `Core`; hygiene PRs on 2.x | differ shows no difference for 2.x against itself; the DLL loads on every matrix leg |
| M1 | `Invoke-Maester` refactored onto the pipeline with only the Pester provider; config resolver with 2.x precedence; `-Config`, `-TestId`, `-ExcludeTestId`; additive result fields except `Source` and `Suite`; config `Selection`, `TestSettings[].Enabled` and `DefaultAction`; `-DryRun` | parity diff empty on the full suite; result JSON unchanged apart from the additive fields; Pester-written XML unchanged; releasable as a 2.x minor |
| M2 | Built-ins run from the module; `suite.json` and `Source`/`Suite`; the `-Path` rules; stale-copy supersede; `Install-`/`Update-MaesterTests` behaviour; side-by-side detection; merged config layers; the section 7.1 fixes | compatibility scenarios automated and green; maester-action release (explicit Pester install step, `include_public_tests: false` mapped to `-SkipBuiltIn`) published before 3.0.0 |
| M3 | **First end-to-end slice:** the attributes, static discovery, catalog, the C# core in single-threaded mode (engine `try`, stream capture, timeouts, Ctrl+C), custom native tests, tenant context with the service and platform gates, Maester-written XML, `Invoke-MtTest`, `Get-MtTest`, `New-MtTest`, `Get-MtTenantContext`, console levels, synthesised `MaesterConfig.TestSettings`, about 10 pilot checks converted with guards and `catch` removed; draft "Writing native tests" and "Upgrading from 2.x" pages | one run with native built-in, Pester built-in, native custom and Pester custom rows in one report; first 3.0 preview with native tests |
| M4 | cis + cisa migrated; docs generator and contributor pages read the catalog for migrated suites and the 2.x sources for the rest | parity |
| M5 | ad migrated | parity on an AD-connected run |
| M6 | Maester + XSPM + AZDO migrated; licence gate; parameter binding with `[MaesterParameter]` kinds and the kind registry; settings registry and `Get-MtSetting`; per-test timeout | parity, including an Azure DevOps-connected run |
| M7 | ORCA and EIDSCA generators emit native files | parity on an Exchange-connected run |
| M8 | Residue and all five families (MT1060 included); check functions no longer exported; shipped config deleted; Pester removed from the manifest and loaded lazily; `-PesterConfiguration` typed `[object]`; `Convert-MtTest`; release candidate | no built-in Pester file ships; a default run on a machine without Pester produces no `Error` rows; unit tests, module-output validation and a dry run of the publish workflows green |
| M9 | Docs, report app, four-week prerelease soak, 3.0.0 | docs build; matrix green |

M3 is the "working `Invoke-Maester` in both formats" end state the RFC asks for;
M4 to M8 move the remaining checks across.

## 16. Decisions

### Ruled by the owner (2026-10-03)

- **PowerShell 7 only.** Windows PowerShell 5.1 is dropped; the manifest requires 7.4
  and the `Core` edition (floor to move to 7.6 when Azure Automation and hosted
  runners do). Four of 66 bug reports with version data were on 5.1; the upgrade page
  says so.
- **Built-in tests always run from the module**; `-SkipBuiltIn` for custom-only
  (section 7.2).
- **Attribute name: `[MaesterTest]`** (and `[MaesterParameter]`).
- **The four author corrections are accepted** (section 11).
- **A custom-test converter ships in 3.0** (`Convert-MtTest`, section 12.1).
- Pester is removed as a dependency in 3.0 and maester-action installs it as an
  explicit step; accepted risk stays host-side; the work lands on `main`; the
  boilerplate `try`/`catch` and the connection and licence guards are removed from the
  tests; tests expose parameters with a UI kind; a `Platform` attribute is added.
- **A C# scheduling core inside the module** (section 5.5): about 700 lines of C# for
  scheduling, timeouts, cancellation, stream capture and the attribute types, committed
  prebuilt so only engine changes need the dotnet SDK; 3.0 runs single-threaded through
  it and parallel later is a default change. The pure-PowerShell alternative (nested
  pipeline plus a watchdog runspace) and a separate engine product were considered and
  not chosen; the evidence is in section 5.5.

### Still open

1. **Contributor seeding rule** (section 11): at least 5 changed lines in a commit
   touching at most 20 files, excluding bots and maintenance commits. Applied unless
   you object; 14 people lose all per-test credit under it.

### Decided by the design unless you object

- The licence property is named `CompatibleLicense` as in ZTA, not `License`.
- The run config is the existing `maester-config.json` shape grown additively, not a
  new document.
- A tenant-specific config file is merged over the base file instead of replacing it.
- A `$null` return is `Skipped`; any uncaught exception is `Error`.
- A test disabled by config stays in the result as a `NotRun` row with a reason.
- The per-test timeout is off by default.
- No `Product` property in 3.0; consumers keep deriving product from `Block`.
- Calling a built-in check function directly from a custom Pester test is unsupported;
  `Invoke-MtTest -Id` replaces it. No "copy under `Custom/` wins" rule.
- A test that threw does not fail the run or the CI XML by default
  (`Output.ErrorsAsFailures`), matching 2.x.
- MT1060's instance IDs are renamed to `MT.1060.<folder>.<n>`.
- The engine DLL is committed to the repository and verified by CI, rather than built
  by every contributor.

## 17. Not yet verified

- **Windows:** the engine DLL, nested-pipeline `BeginStop` and the dynamic-module
  binding were verified on PowerShell 7.4 (Linux) and 7.6 (macOS), not on Windows.
- **Windows file locking of the loaded engine DLL** and Authenticode signing of the
  DLL were not exercised (macOS and Linux only).
- **Ctrl+C in an interactive console** was proven in two halves (a real SIGINT to
  `pwsh -File`, and the engine's own stop path with runspace reuse afterwards), not as
  one interactive session; PSReadLine broke the pseudo-terminal harness.
- **Linux and case-sensitive file systems:** most experiments ran on macOS. Discovery
  of lower-case `.tests.ps1` files and path matching for `ExcludeLine` need a Linux
  run, since maester-action and hosted runners run there.
- **Session reuse across runspaces** for Exchange, Teams, SharePoint, Az and LDAP is
  taken from ZTA's source, not tested. It only matters for the later parallel work.
- **Multi-result families:** only MT.1024 has executed rows in the available result
  files; the other families' behaviour is taken from their wrappers.
- **GCC detection** through the OpenID metadata field `tenant_region_sub_scope` is used
  by CISA ScubaGear but is not documented by Microsoft; the design does not rely on it.
- **Parity on connected services:** the AD, ORCA and AZDO milestones need runs
  connected to those services; CI has only a Graph smoke tenant.
- **Side-by-side detection** was reproduced with synthetic 2.x and 3.0 modules, not
  with the published 2.2.85 against a built 3.0.
- **`Merge-MtMaesterResult` and `Compare-MtTestResult`** over mixed 2.x and 3.0 files:
  additive fields are expected to pass through; untested.
- **Constrained Language Mode:** no change from 2.x. Maester already defines classes
  and cannot be imported under CLM.
- **Private repositories** are invisible to the custom-test survey; every "nobody does
  this" is a public lower bound.
- **Pester versions** other than 5.7.1 and 6.0.0 were not executed.
- **Partition merge** (section 13.1) is a design sketch; `Merge-MtMaesterResult`'s
  same-run mode has not been prototyped.

## Appendix A: Specification details

### A.1 Reason codes

A closed list. Additions are minor-version changes.

| `Result` | Reason codes |
| --- | --- |
| `NotRun` | `NotSelected`, `NotListed`, `DryRun`, `ExcludedByTag`, `ExcludedById`, `DisabledByConfig`, `Preview`, `LongRunning`, `OptInServiceNotConnected`, `DeselectedAtRuntime` |
| `Skipped` | `ServiceNotConnected`, `ServiceNotRegistered`, `LicenseNotFound`, `TenantTypeMismatch`, `CloudMismatch`, `PlatformMismatch`, `NotApplicable`, `NoInstances`, `NoResult`, `TestSkipped` |
| `Error` | `TestError`, `Timeout`, `InvalidMetadata`, `InvalidConfiguration`, `InvalidReturn`, `InvalidInstanceId`, `DuplicateId`, `LoadFailed`, `InstanceSourceFailed`, `RequiresNewerMaester`, `ForeignModuleLoaded`, `PesterNotAvailable` |

For `TestSkipped` the legacy code (for example `NotConnectedExchange`) stays in
`ResultDetail.TestSkipped`.

`NotSelected` means the test matched no include; `ExcludedByTag` and `ExcludedById` mean
it matched an exclude. `LoadFailed` means the file could not be parsed or loaded.
`InvalidMetadata` also covers a custom native test with no `.md` beside it. `NoInstances`,
`InstanceSourceFailed` and `InvalidInstanceId` mean the family's source returned nothing,
threw, or returned an `Id` outside the instance grammar; each is one row on the parent ID.

### A.2 XML outcome mapping

Nearly every `Error` row today comes from the boilerplate `-SkippedBecause Error`,
which Pester wrote as ignored. In 3.0 the same exceptions are caught by the engine, so
mapping every `Error` row to a failure would newly fail pipelines that set
`failTaskOnFailedTests`. The default keeps parity; `Output.ErrorsAsFailures = true`
opts in.

| Row | XML outcome |
| --- | --- |
| `Passed` | success |
| `Failed` | failure |
| `Error` raised by the engine without running the test (`InvalidMetadata`, `InvalidConfiguration`, `InvalidInstanceId`, `DuplicateId`, `LoadFailed`, `InstanceSourceFailed`, `RequiresNewerMaester`, `ForeignModuleLoaded`, `PesterNotAvailable`) | failure, with message |
| `Error` from the test (`TestError`, `InvalidReturn`, `Timeout`, or `-SkippedBecause Error`) | ignored, with the message; failure when `Output.ErrorsAsFailures` is true |
| `Skipped` | ignored, with `ReasonDetail` |
| `Investigate` | success if the test returned `$true`, failure if `$false`, ignored if it returned nothing |
| `NotRun` | omitted, as Pester does today |

The test-case name is `<Block>.<Name>`, as Pester writes it, so Azure DevOps test
history stays continuous. When Maester writes the file, Pester's own writer is
disabled for the provider call. NUnit 3 is not written by Maester; if requested, it is
left to Pester's writer for Pester rows with a warning that native rows are absent.
The prototype XML writer (session scratchpad, appendix B) maps every `Error` row to a
failure and must be corrected to this table.

### A.3 `-PesterConfiguration` keys

| Key | 3.0 behaviour |
| --- | --- |
| `Run.Path` | used as `-Path` when `-Path` is not bound, as 2.x does |
| `Filter.Tag` | the include-tag set when neither `-Tag` nor `Selection.Tag` is given; applies to native and Pester tests |
| `Filter.ExcludeTag` | unioned with `-ExcludeTag`, `Selection.ExcludeTag` and the defaults |
| `TestResult.*` | served by the Maester XML writer |
| `Output.Verbosity` | overridden by `-Verbosity`, as today |
| `Filter.ExcludeLine`, `Run.ExcludePath` | Pester provider only; the engine appends, never replaces |
| `Run.Container`, `Run.ScriptBlock`, `TestRegistry.*`, `Should.*`, `Debug.*` | passed through |
| `Filter.FullName`, `Filter.Line` | passed through, with a warning that they cannot select native tests |
| `Run.PassThru` | forced to true |
| `Run.Parallel`, `Run.FailOnNullOrEmptyForEach` | forced to false where the option exists (Pester 6 only) |

For Pester tests the engine never sets `Filter.FullName` or `Filter.Line` itself:
`FullName` cannot exclude and unions with tags, and `Line` runs tests marked `-Skip`.
"Include only these IDs" is expressed as excluding every other known line.

### A.4 Catalog contract

`Maester.TestCatalog.json` sits in the module root. Top level: `SchemaVersion`;
`CatalogVersion` (equal to the module version, echoed in results); `GraphPermissions`
(the `Get-MtGraphScope` lists, run-level); `Suites` (the `suite.json` contents);
`Tests`. Each test row holds the attribute properties plus `Source`, `Suite`, the
effective tag set, the resolved `HelpUrl`, `FunctionName`, `File`, `Parameters` (name,
type, default, allowed values, range, description), `IdPattern` for a family, and the
settings the test reads (derived from the call graph at build time). The file lists
built-in native tests only, one row per family. `Get-MtTest -Path` covers custom tests;
family instance IDs are known only from results.

### A.5 Parameter values from config

| Parameter type | Accepted JSON value |
| --- | --- |
| `int` | an integral number within the Int32 range |
| `bool` / `switch` | true or false |
| `string` | a string |
| `string[]` | a string or an array of strings |

Rejected with `InvalidConfiguration`: a name that is not in the test's `param()` block,
fractional numbers, a number for a string, a string for a switch or an integer, a value
outside the parameter's `ValidateRange` or `ValidateSet`, abbreviated names,
common-parameter names and engine-owned names. As a backstop, a parameter-binding
exception raised while binding the test function itself is also `InvalidConfiguration`.
A `DateTime` that arrives for a `string` parameter (JSON date conversion on PowerShell
7.4, or an object passed to `-Config`) is converted back with the round-trip format; it
is never passed culture-formatted.

### A.6 `Source` and `Suite` on a row

In order:

1. A test in a suite folder (native, or a built-in Pester file) takes its manifest's
   `Source` and `Id`.
2. Any other custom test, or a package test until consumers understand packages:
   `Source = Custom`, `Suite = Custom` (a package also sets the reserved `Package`
   field).
3. When the engine cannot tell, it omits both, and consumers fall back to their own
   rule. M1 has no manifests, so it emits neither.

## Appendix B: Evidence

Two data inputs the implementation needs are in
`docs/proposals/maester-3.0-evidence/`:

| Item | File |
| --- | --- |
| ID to function to file map for all 750 checks | `idmap.csv` |
| Authorship seed for all 750 checks, 12 rule variants | `authorship-seed.csv` |

The research reports (16), the three design proposals, the decision matrix, the review
findings, the prototypes (native and legacy runner, parameter binding, multi-result,
Pester selection by ID, XML writer), the C# core spike (`experiments/csharp-engine/`,
with `Maester.Engine/*.cs`, the fake host module and the run outputs) and the
prior-art notes on PSFramework, ZTA, Pester 6 and ThreadJob
(`experiments/prior-art-parallel/`) are in the session scratchpad, which is temporary.
They were not copied into this public repository because they describe private
product internals and name third-party repositories. They are not normative: where they differ
from this document, this document wins.

Scratchpad root:
`/private/tmp/claude-501/-Users-merill-github-maester--claude-worktrees-maester-3-planning-6643a9/d1c36d8f-a780-4225-bb8f-6c8aa134cb55/scratchpad`
(`research/`, `design/`, `experiments/`).

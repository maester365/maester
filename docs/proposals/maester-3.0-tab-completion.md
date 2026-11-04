# Maester 3.0 tab completion: design

Status: accepted and implemented in one pull request (steps 1 to 3 below), following the owner's ruling of
2026-11-03: "one PR 1-3". The questions at the end were not answered separately, so the recommendations stand.
"Implementation notes" says where the code differs from the design.

Goal: pressing Tab after `-Product`, `-TestId`, `-Pack` and the other selectors of `Invoke-Maester` completes their
values from what Maester knows (the taxonomy, the test catalogue, the suites, the installed packs and the custom
tests under `-Path`), with a tooltip that says what each value is. The same completers serve every command that
takes the same parameter.

## What ZeroTrustAssessment does

Read from ZeroTrustAssessment 3.1.0 as installed from the PowerShell Gallery (`scripts/ArgumentCompleters.ps1`,
`public/Get-ZtTest.ps1`).

| Aspect | ZeroTrustAssessment |
| --- | --- |
| Mechanism | `Register-ArgumentCompleter -CommandName Get-ZtTest, Invoke-ZtAssessment, Invoke-ZeroTrustAssessment -ParameterName Tests` in a script the `.psm1` dot-sources at import. Because the script block is created inside the module, it runs in module scope and calls private functions. `-Pillar` uses PSFramework instead: `Register-PSFTeppScriptblock` plus a `[PsfArgumentCompleter('ZeroTrustAssessment.Tests.Pillar')]` attribute. |
| Data | `Get-ZtTest`, which on first use parses every `Test-Assessment-*` function for its `[ZtTest]` attribute and caches the result in `$script:__ZtSession.TestMeta`. |
| Matching | Prefix on the test ID first, then a word match in the title, category and risk level, with a synonym table (`mfa`, `ca`, `pim`, `sspr`, `aad`). Several words, typed in quotes, must all match. Sorted by match quality, then by numeric ID. |
| Display | `CompletionText` is the ID; `ListItemText` is `"<id> - <title> [<category>]"`; `ToolTip` is the title, category and risk level on separate lines. |
| Arrays | Splits the word on `,` and completes the last part. Trims quotes from the word. |
| Paging | Returns at most 10 results (a PSFramework setting) plus a fake `...` entry whose tooltip says how many more there are. |
| Failures | A `try`/`catch` around everything; the error goes to `Write-Debug` and the completer returns nothing. |

What to take: registering from inside the module so the completer reaches private data, one completer shared by
several commands, an ID prefix match before a title search, and the ID/title/tooltip layout.

What to leave:

- The PSFramework dependency. Maester doesn't have one and a completer doesn't need one.
- The fake `...` entry. Choosing it inserts `...` into the command line. PSReadLine already asks before showing a long
  list, and Maester narrows the list by the other parameters on the line (below), so no cap is needed.
- The synonym table. Maester's taxonomy has aliases (`EXO`, `Entra ID`) and display names already; those are the
  synonyms.
- Results that aren't quoted. ZeroTrustAssessment's values never contain spaces, but the values of custom tests and
  packs can.
- Comma splitting is harmless but unnecessary: PowerShell 7 already passes only the element being completed (tested
  below).

## What PowerShell does with a completer (measured on PowerShell 7.6.2)

A probe module registered a completer for two `[string[]]` parameters and logged what it received:

| Typed | `$wordToComplete` | `$fakeBoundParameters` | Notes |
| --- | --- | --- | --- |
| `-Product en` | `en` | `Product=en` | |
| `-Product entra,ex` (or `entra, ex`) | `ex` | `Product=entra,ex` | Only the current element is the word; the earlier ones are in the bound value, so they can be left out of the list. |
| `-Product entra,` | empty | nothing | After a trailing comma the earlier values aren't available. |
| `-Product 'Ent` | `'Ent'` | `Product=Ent` | The word keeps its quotes, with the closing one added, and the replacement range covers the quote. A result must carry the quotes itself. |
| `-Path ./x -Product exchange -Feature co` | `co` | `Feature=co; Product=exchange; Path=./x` | The other parameters on the line are available, so a completer can narrow by them. |
| `Invoke-ProbeAlias -Product en` | `en` | | A completer registered for the command also serves its alias (`Invoke-MtMaester`). |

Also confirmed:

- `Register-ArgumentCompleter -ParameterName` takes one name, so registration loops over the parameters.
- A script block created inside a module function and passed to `Register-ArgumentCompleter` runs in module scope.
- A script block in an `[ArgumentCompleter({...})]` attribute does **not**. This is why `Get-MtRoleMember -Role Glob<Tab>`
  returns nothing today: its completer calls the private `Initialize-MtRoleDefinition`, which isn't visible from where
  the attribute's script block runs (0 completions, while the same call in module scope finds 144 roles). The
  `-Service` completers of `Connect-Maester` and `Test-MtConnection` work around it with
  `& (Get-Module Maester | Select-Object -First 1) { ... }`, which picks an arbitrary module when two versions are
  loaded.
- When a completer returns nothing, PowerShell falls back to completing file names. A value with no match therefore
  shows files, as it does for ZeroTrustAssessment. This can't be turned off from a completer.

## Mechanism: one registration table, run at import

`Get-MtArgumentCompleterTable`, a private function, returns rows of `Command`, `Parameter`, `Kind`, `Values` and
`Narrow`. `Register-MtArgumentCompleter` calls `Register-ArgumentCompleter` once for each row with one script block.
The script block is created in the function, so it is bound to the module that registered it, and it calls one
dispatcher, which looks the row up by command and parameter:

```powershell
$completer = { Get-MtArgumentCompletion -CommandName $args[0] -ParameterName $args[1] -WordToComplete $args[2] -FakeBoundParameters $args[4] }
```

`GetNewClosure()` is not used: it binds a script block to a new dynamic module, which loses the module scope. For an
alias (`Invoke-MtMaester`), PowerShell passes the command's own name, so the table needs no alias rows.

The source `Maester.psm1` calls `Register-MtArgumentCompleter` after it dot-sources the functions. The build writes
its own tail for the consolidated `Maester.psm1` (`Build-MaesterModule.ps1`, after `Export-ModuleMember`), so the
same call is added there. `Test-MaesterModuleOutput.ps1` checks the built module completes a value.

Why this and not the alternatives:

| Option | Verdict |
| --- | --- |
| `[ArgumentCompleter({...})]` on each parameter | Rejected. The script block isn't in module scope, so each one needs the `& (Get-Module Maester ...)` wrapper; about 30 copies across the commands, each a place to get wrong (the `Get-MtRoleMember` bug). It also crowds the parameter blocks that the help is generated from. |
| `Register-ArgumentCompleter` from one table (chosen) | One place lists what completes; bound to the exact module instance that registered it; a unit test can walk the table. Re-importing the module re-registers and replaces the old entries. After `Remove-Module`, the old script block finds nothing and returns nothing. |
| An `IArgumentCompleter` class in `Maester.Engine.dll` | Rejected. The data, its caches and the selection rules are in PowerShell; a C# completer would call back into the module for all of it, and every change would mean rebuilding and committing the DLL. |
| `[ValidateSet()]` | Rejected for the selectors. It would reject what the parameters accept today: `'*'` wildcards (`-Product 'entra*'`, `-Severity Crit*`), aliases (`'Entra ID'`, `exo`), the products and features of custom tests and packs, and test IDs. It is still right for the closed enums that have it (`-Verbosity`, `-OutputMode`, `-RedactUserIdentity`), which complete already. |
| `[ArgumentCompletions()]` | Static values only, no tooltips, no narrowing. Not needed once one dispatcher exists. |
| `DynamicParam` | Rejected. It runs on every parameter binding, including while completing the other parameters, it hides the parameters from the generated help and the command pages on maester.dev, and it makes the parameter set depend on files on disk. |

## The dispatcher and its rules

`Get-MtArgumentCompletion -Kind <kind> ...` returns `[System.Management.Automation.CompletionResult]` objects. For
every kind:

1. **Never fail, never write.** The body runs in `try`/`catch` with `$WarningPreference`, `$ProgressPreference` and
   `$InformationPreference` set to `SilentlyContinue`; on an error it returns nothing (and writes the error to
   `Write-Debug`, as ZeroTrustAssessment does). A warning written during completion lands in the middle of the
   command line.
2. **Never reach the network or run code from tests.** No Graph, GitHub or gallery calls, no Pester discovery (it
   runs `BeforeDiscovery` and `Describe` code), no pack module imports, no loader gate, no
   `Register-MtPackService`. Native tests and packs are read statically.
3. **Clean the word.** Strip the leading quote and the closing quote PowerShell adds, remember which quote the user
   typed, and take the text after the last comma (harmless on PowerShell 7, needed if a host passes the whole
   array).
4. **Leave out values already on the line.** The earlier elements of the same parameter, from
   `$fakeBoundParameters`, are not offered again.
5. **Narrow by the other selectors on the line**, with the engine's own rules (`Resolve-MtSelection`,
   `Test-MtSelectorMatch`, `Test-MtProductExcluded`, `Test-MtIdMatch`), so aliases and wildcards mean the same as
   they do in a run. The selectors combine with AND, so a value that matches no test given the others would select
   nothing; it isn't offered. With no other selector on the line, every known value is offered.
6. **Rank.** (1) the value starts with the word; (2) an alias or display name starts with the word (`exo` →
   `exchange`); (3) every word of the search appears in the name, title or description (`'phishing resistant'`).
   Within a rank: the taxonomy's own order for products, Critical to Info for severities, natural sort for IDs
   (`MT.1005` before `MT.1010`, `CIS.M365.1.1.10` after `CIS.M365.1.1.9`).
7. **Insert the key, show the name.** `CompletionText` is the value the parameter takes (`exchange`, never
   `Exchange Online`); `ListItemText` adds a short hint; `ToolTip` explains it and gives a test count.
8. **Quote when needed** (`ConvertTo-MtCompletionResult`). If the user started with a quote, the result uses the same
   quote and closes it. Otherwise a value is wrapped in single quotes (escaped with
   `[System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent`) when it contains
   whitespace or one of `` , ; ( ) { } [ ] @ $ # ` ' " | & < > ``, or starts with `-`. Dots, hyphens, `*` and `:`
   need no quotes: `-TestId CISA.MS.AAD.3.1`, `MT.1024.*` and `cis-m365:5.1.5.1` all bind as strings, and the unit
   tests check that each built-in value round-trips through the parser unchanged.

## Where the data comes from, and how fast

Measured on this machine:

| Source | Cold | Warm |
| --- | --- | --- |
| Import the built module (3.0.0) | 484 ms | |
| `Maester.TestCatalog.json` (1.5 MB, 891 tests): `Get-Content -Raw \| ConvertFrom-Json` | 48 ms | |
| `Get-MtTestCatalog` on the built module (the JSON plus array clean-up per row) | 537 ms | 0 ms (cached) |
| `Get-MtTestCatalog` in a source checkout (scans `tests/`) | 3,382 ms | 0 ms |
| `Get-MtTaxonomy` | under 10 ms | 0 ms |
| `Get-MtLegacyTagTable` (169 tags) | 9 ms | 0 ms |
| `Initialize-MtPackSet` (2 packs) | 223 ms | |
| `Get-MtPackTestInventory` (ZTA and a demo pack) | 433 ms | 69 ms |

`Maester.Engine.dll` holds no test metadata (the `[MaesterTest]` attribute class, the run cmdlet and the console
renderer), so it isn't a data source. The data comes from:

**`Get-MtCompletionIndex`** (cached in `$script:__MtCompletionIndex` for the session; the data is fixed for a module
version). It holds, for each built-in test, only what completion uses: `Id`, `Title`, `Product`, `RelatedProduct`,
`Feature`, `Area`, `Severity`, `Suite`, `Control`, `Benchmark`, `Lifecycle`, `LongRunning`, `SuiteTag`; plus the
taxonomy lookups, the legacy tags with their `Replacement`, and the suite names from each `suite.json` (`CISA SCuBA
baselines`).

- If `Get-MtTestCatalog` has already run in this session (any `Invoke-Maester` or `Get-MtTest`), the index is
  projected from its cache.
- Otherwise, in the built module, it reads `Maester.TestCatalog.json` itself with `ConvertFrom-Json` and projects the
  rows with a plain `foreach` (no pipeline, no per-row `Where-Object`). Target: the first completion in a session under
  150 ms, the next ones under 30 ms.
- In a source checkout it falls back to `Get-MtTestCatalog` (about 3.4 s once per session). Only contributors see
  this.

**Custom tests**, when a command would run them: `-Path` on the line, or for `Invoke-Maester` without `-Path`, the
`./Custom` folder (the default the command uses). Found with the same discovery `Invoke-Maester` uses (native
`Test.*.ps1` anywhere under the path, three levels deep) and read with `Get-MtNativeTestInventory`, which parses
statically. Cached by resolved path, with a fingerprint of the file count and the newest `LastWriteTimeUtc`, so a new
test shows up without restarting. Pester-format tests (`*.Tests.ps1`) contribute nothing: their tags and IDs are
known only after Pester discovery, which runs their code.

**Packs** (`Read-MtPackList`, new, in `internal/packs/`): the built-in packs' `maester-pack.json` under the module's
`packs/` folder, plus the entries of the lock file the command would use (`-PackLock` on the line, else
`MAESTER_PACK_LOCK`, else the lock beside the config found from `-Path` or the current folder, through
`Resolve-MtPackLockPath`). It reads JSON only: `Id`, `Code`, `Name`, `Version`, `Publisher`, status. Cached by lock
path and the lock file's `LastWriteTimeUtc`. If `$script:__MtPackSet` is already loaded, it is used instead.

**Pack tests**, when `-Pack` or `-AllPacks` is on the line: the named packs' tests, read statically, and for a family
whose instances come from a JSON file in the pack (the ZTA pack's `catalog.json`, `ZTA.21770` and so on) the instance
IDs and titles from that file. Cached per pack root and version.

## Parameter by parameter: `Invoke-Maester`

| Parameter | Completes | Source | Narrowed by | Tooltip |
| --- | --- | --- | --- | --- |
| `-Path` | Paths | PowerShell's own path completion | | |
| `-Tag` | Tags that select tests: the Maester 2.x tags, suite tags, and the tags of native custom tests | Legacy tag table, catalogue `SuiteTag`, custom tests | The other selectors | Number of tests; for a 2.x tag with a replacement, "Maester 2.x tag. `-Feature conditional-access` selects the same tests." |
| `-ExcludeTag` | As `-Tag` | As `-Tag` | The other selectors | As `-Tag` |
| `-Product` | Product keys | Taxonomy, plus the products of custom and pack tests | `-Suite`, `-Area`, `-Severity`, `-Feature`, `-Pack` | Name, aliases, number of tests |
| `-ExcludeProduct` | Product keys | As `-Product` | Not narrowed (excluding is allowed for anything) | As `-Product` |
| `-Feature` | Feature keys | Taxonomy features of the products in `-Product` (aliases resolved), or of all products; plus custom and pack test features | `-Product` first, then the others | Name and product, e.g. "Conditional Access (Entra ID)", number of tests. A key several products share (`anti-phishing` is both Exchange and Defender) appears once, listing them. |
| `-Area` | Area keys | Taxonomy | The other selectors | Name and the taxonomy's description |
| `-Severity` | `Critical`, `High`, `Medium`, `Low`, `Info` | Fixed list, in that order | The other selectors | Number of tests |
| `-Suite` | Suite names | Distinct `Suite` of the tests in scope (built-in: AD, ASD, CIS, CISA, EIDSCA, Maester, ORCA, XSPM) | The other selectors | `suite.json` `Name`, number of tests |
| `-Pack` | Pack codes (`ZTA`), then pack IDs (`maester.zero-trust-assessment`) | `Read-MtPackList` | `-PackLock`, `-Path` | Name, version, publisher, built-in or installed, number of tests |
| `-AllPacks`, `-IncludeLongRunning`, `-IncludePreview`, `-IncludeAffectedObjects`, `-ExcludeAffectedObjects`, `-NonInteractive`, `-PassThru`, `-SkipGraphConnect`, `-DisableTelemetry`, `-SkipVersionCheck`, `-ExportCsv`, `-ExportExcel`, `-NoLogo`, `-DryRun`, `-SkipBuiltIn`, `-SkipPack` | Switches | | | |
| `-OutputHtmlFile`, `-OutputMarkdownFile`, `-OutputMarkdownSummaryFile`, `-OutputJsonFile`, `-OutputFolder`, `-DriftRoot`, `-PackLock` | Paths | PowerShell's own path completion | | |
| `-Config` | Paths | PowerShell's own path completion (the parameter is `[object]`, so a filter to `*.json` adds little) | | |
| `-RedactUserIdentity`, `-Verbosity`, `-OutputMode` | Their `ValidateSet` values | Already complete; no change | | |
| `-OutputFolderFileName` | Nothing | Free text | | |
| `-PesterConfiguration` | Nothing | An object | | |
| `-MailRecipient`, `-MailUserId`, `-TeamId`, `-TeamChannelId` | Nothing | Would need Graph calls during completion: slow, and outside the session cache. Not completed. | | |
| `-MailTestResultsUri`, `-TeamChannelWebhookUri` | Nothing | Free text | | |
| `-TestId` | Test IDs, and wildcard groups | Built-in tests; custom tests under `-Path` (or `./Custom`); tests of the packs in `-Pack`/`-AllPacks`; the ZTA family instances | `-Product`, `-ExcludeProduct`, `-Feature`, `-Area`, `-Severity`, `-Suite`, `-SkipBuiltIn` (drops built-in tests) | Title; product › feature · severity · suite; benchmark requirement; Preview or Long-running when it applies (an exact ID runs those anyway) |
| `-ExcludeTestId` | As `-TestId` | As `-TestId` | As `-TestId`, plus `-TestId` (only IDs that would otherwise run) | As `-TestId` |

`-TestId` and `-ExcludeTestId` in more detail:

- **Prefix on the ID** first: `MT.100<Tab>` lists `MT.1001` to `MT.1009`.
- **Wildcard groups**: when the word matches several IDs, the next ID segment is offered as a wildcard before the
  single IDs. `CISA.MS.<Tab>` offers `CISA.MS.AAD.*`, `CISA.MS.EXO.*` and `CISA.MS.SHAREPOINT.*`, each with its test count,
  then the IDs. `MT.1024.<Tab>` offers `MT.1024.*`, the instances of that family: they come from a function that
  reads Graph at run time, so only the wildcard is offered, not the instance IDs. This writes the patterns the parameter's help already
  shows.
- **Requirement search**: the word also matches a test's `Control` references and `Benchmark`, so
  `MS.AAD.3.1<Tab>` or `cis-m365:5.1.5.1<Tab>` lists every test that implements that requirement, in any suite
  (shims included). This is where the framework files are used: no parameter takes a framework key or requirement
  ID today. If a `-Control` selector is added later, it becomes one more kind in the table, completing
  `<framework-key>:<requirement-id>` from the framework index (`Get-MtFrameworkIndex`).
- **Title search**: anything that isn't an ID prefix searches the title and the product and feature names; several
  quoted words must all appear (`'phishing resistant'<Tab>`).
- `ListItemText` is `MT.1005  <title>`, with the title cut to fit about 80 characters.

## Other commands that share the completers

| Command | Parameters | Kind | Notes |
| --- | --- | --- | --- |
| `Get-MtTest` | `-Id`, `-Tag`, `-Product`, `-Feature`, `-Area`, `-Severity`, `-Suite` | TestId, Tag, Product, Feature, Area, Severity, Suite | Custom tests only when `-Path` is given (it doesn't read `./Custom`). |
| `Invoke-MtTest` | `-Id` | TestId | Built-in tests, or the tests under `-Path`. |
| `New-MtTest` | `-Product`, `-Feature`, `-Area` | Product, Feature, Area | Taxonomy keys only, not narrowed by tests: an author is choosing a key, and the taxonomy is the list of allowed keys. |
| `New-MtTest` | `-ResourceType`, `-Mitre`, `-Service` | ResourceType, Mitre, Service | Taxonomy `ResourceTypes` with descriptions; ATT&CK technique IDs with names from `Get-MtAttackData` (retired ones left out); the services from the service registry. |
| `Get-MtPack`, `Restore-MtPack` | `-Id` | Pack | |
| `Update-MtPack`, `Uninstall-MtPack` | `-Id` | InstalledPack | Installed packs only; a built-in pack can't be updated or uninstalled. |
| `Connect-Maester`, `Test-MtConnection`, `Get-MtConnector` | `-Service` | Service | Moved into the table from the attribute completers they have today; `Get-MtServiceCompletion` (a second function in `Resolve-MtRequestedService.ps1`) moves to its own file. |
| `Get-MtSetting` | `-Name` | Setting | Setting names from `assets/MaesterSettings.psd1`, with their `Description` as the tooltip. |
| `Get-MtRoleMember` | `-Role` | Role | Fixes the broken completer described above. |

Not completed: `Install-MtPack -Source` (a gallery or Git source; would need the network), `Get-MtTestInventory`
(Pester-format inventory; `-ExcludeTag` would need Pester discovery), `Invoke-MtTest -Parameter` (hashtable keys;
PowerShell gives a completer no reliable way to complete keys inside a hashtable literal).

## Files

All new functions are private, one function per file, `Verb-Noun.ps1`, UTF-8 with BOM.

| File | Job |
| --- | --- |
| `powershell/internal/engine/completion/Get-MtArgumentCompleterTable.ps1` | The `Command`/`Parameter`/`Kind` table. |
| `powershell/internal/engine/completion/Register-MtArgumentCompleter.ps1` | The registration loop. |
| `powershell/internal/engine/completion/Get-MtArgumentCompletion.ps1` | The dispatcher: rules 1 to 8 above. |
| `powershell/internal/engine/completion/Get-MtCompletionCandidate.ps1` | The candidates of each kind, in order, with their tooltips. |
| `powershell/internal/engine/completion/Get-MtCompletionIndex.ps1` | The cached index of built-in tests and suite names. |
| `powershell/internal/engine/completion/Get-MtCompletionTestSet.ps1` | The tests a command line is about: built-in, custom under `-Path`, pack tests; narrowed by the selectors on the line. |
| `powershell/internal/engine/completion/Get-MtCompletionCustomTest.ps1` | The native custom tests under a folder, cached until the files change. |
| `powershell/internal/engine/completion/ConvertTo-MtCompletionTest.ps1` | What completion keeps of a test row. |
| `powershell/internal/engine/completion/ConvertTo-MtCompletionResult.ps1` | Quoting and the `CompletionResult`. |
| `powershell/internal/packs/Read-MtPackList.ps1` | Read-only list of built-in and locked packs, from JSON. |
| `powershell/internal/services/<service>` | Unchanged; `Get-MtRoleMember`'s data access stays where it is. |
| `powershell/Maester.psm1`, `build/Build-MaesterModule.ps1` | One `Register-MtArgumentCompleter` call each. |

The completers sit under `internal/engine/` because every one of them reads the engine's catalogue and must narrow
with the engine's selection rules. `internal/session/` (console and telemetry) was the other candidate.
`RepositoryLayout.Tests.ps1` checks only the first folder level under `internal/`, so the `completion/` subfolder
needs no change there.

## Unit tests

New file `powershell/tests/functions/engine/ArgumentCompletion.Tests.ps1`. Tests call `TabExpansion2` against the
imported module, so they exercise the registration, the module binding and the parsing of the word together.

- **Table**: every row names an exported command and one of its parameters; every exported command's parameter named
  `Product`, `ExcludeProduct`, `Feature`, `Area`, `Severity`, `Suite`, `Tag`, `ExcludeTag`, `TestId`,
  `ExcludeTestId` or `Pack` has a row (so a new command with a selector can't miss completion).
- **Product**: `en` gives `entra` first; `exo` gives `exchange`; the tooltip has the display name; `-Product entra,<word>`
  leaves `entra` out.
- **Feature**: with `-Product exchange`, `conditional-access` isn't offered; with `-Product 'Entra ID'` (an alias) it is.
- **Area, Severity, Suite**: the values match the taxonomy, the fixed order and the catalogue's suites.
- **TestId**: `MT.100` returns only IDs that start with it; `CISA.MS.` returns segment wildcards with counts first;
  `-Suite CIS` leaves out non-CIS IDs; `MS.AAD.3.1` finds the CISA test by its Control; a quoted title search finds
  a test by two words; `-SkipBuiltIn` leaves out built-in tests.
- **Path**: a fixture folder under `powershell/tests/fixtures/` with a native custom test whose product is
  `'My Product'` and whose ID is `CUSTOM.1`: `-Path <fixture> -TestId CUS` finds it; `-Product My` completes to
  `'My Product'` with quotes; a word typed as `"My` keeps double quotes.
- **Parsing**: every completion text for the built-in values parses back (`[Parser]::ParseInput`) to one string
  argument equal to the value.
- **Packs**: `-Pack ZT` gives `ZTA`; a fixture lock file adds an installed pack; `Uninstall-MtPack -Id` offers no
  built-in pack.
- **Safety**: with `Get-MtCompletionIndex` mocked to throw, completion returns nothing and writes no error record and
  no warning.
- **Scope regression**: `Get-MtRoleMember -Role <word>` returns role names (it returns none today).
- **Built module**: `Test-MaesterModuleOutput.ps1` checks that `Invoke-Maester -Product exo<Tab>` completes on the
  built module.

Timing isn't asserted in unit tests (too noisy on CI runners); the pull request reports the cold and warm timings
measured on the built module.

## Implementation steps

1. **Infrastructure and taxonomy selectors.** `Register-MtArgumentCompleter`, `Get-MtArgumentCompletion`,
   `Get-MtCompletionIndex`, `ConvertTo-MtCompletionResult`; the psm1 and build calls; kinds Product, Feature, Area,
   Severity, Suite for `Invoke-Maester`, `Get-MtTest` and `New-MtTest`; their tests.
2. **Test IDs and tags.** `Get-MtCompletionTestSet` with custom tests under `-Path`; kinds TestId (prefix, wildcard
   groups, requirement search, title search, narrowing) and Tag for `Invoke-Maester`, `Get-MtTest` and
   `Invoke-MtTest`; the fixture and tests.
3. **Packs and the existing completers.** `Read-MtPackList`; kinds Pack and InstalledPack, and pack test IDs; move
   `-Service` into the table and `Get-MtServiceCompletion` into its own file; fix `Get-MtRoleMember`; kinds
   ResourceType, Mitre, Service and Setting for `New-MtTest` and `Get-MtSetting`.
4. **Docs.** A line in each affected command's `.DESCRIPTION` ("Press Tab after -Product to list the products"),
   which regenerates the command pages, and a sentence in `website/docs/writing-tests/index.mdx` about completing
   `New-MtTest`'s attribute values.
5. Run `./powershell/tests/pester.ps1`, build with `./build/Build-MaesterModule.ps1`, validate with
   `./build/Test-MaesterModuleOutput.ps1`, and measure the first and later completions on the built module.

One pull request with a commit per step, or steps 1 and 2 first and step 3 as a second pull request.

## Implementation notes

What changed from the design while it was built, and why:

- **Speed.** The first measurement of `-TestId` completion was 300 to 430 ms on every Tab. Three changes brought a
  warm completion to 5 to 20 ms: each test's candidate (tooltip, list text, search text) is made once and kept on
  its cached row (`Candidate`); the IDs are sorted with `[System.Array]::Sort[string, object]` on a padded `SortKey`
  with an ordinal comparer (the non-generic overload sorted a copy of the items; a culture sort ignores hyphens);
  and the narrowing in `Get-MtCompletionTestSet` matches with plain loops instead of calling
  `Test-MtSelectorMatch`, `Test-MtProductExcluded` and `Test-MtIdMatch` for every test. It still resolves product
  aliases with `Resolve-MtSelection`, and the loops match the same way (`-like` on each value, IDs exact or with `*`).
- **The first Tab.** On the built module, the first completion in a session took 640 to 800 ms. Most of it was the
  natural sort key, made with a script block `MatchEvaluator` (408 ms for 891 tests; two plain `-replace` calls take
  40 ms), and pipelines in each test's tooltip (230 ms; plain statements take 88 ms). Measured afterwards, with the
  unit tests running on the same machine: 280 to 320 ms for the first Tab, 9 to 33 ms after. That misses the 150 ms
  target: about 50 ms is reading `Maester.TestCatalog.json`, 40 ms converting its rows, 20 ms the legacy tags, 90 ms
  the test-ID tooltips and about 70 ms PowerShell's own completion work on the first call.
- **Search needs three characters.** Rule 6's word search inside names and titles applies only to a word of three
  characters or more: with two, `en` offered `defender`.
- **Duplicates.** The dispatcher drops a value it has already offered, so a test ID that is both built in and under
  `-Path` is listed once.
- **Pack kinds.** `Pack` (`Invoke-Maester -Pack`: codes, then IDs), `PackId` (`Get-MtPack`: every pack) and
  `InstalledPackId` (`Update-MtPack`, `Uninstall-MtPack` and `Restore-MtPack`: the lock file's packs that don't ship
  with Maester). An installed pack's tests and services come from its lock entry; a built-in pack's tests from its
  `Catalog` file.
- **`-ExcludeProduct`** is the table's one row with `Narrow = $false`: its list depends only on which tests there are
  (`-Path`, `-Pack`, `-AllPacks`, `-PackLock`, `-SkipBuiltIn`), not on the other selectors.
- **Custom tests** add one function, `Get-MtCompletionCustomTest`, which caches per folder until the files change.
  Its rows and the catalogue's come from `ConvertTo-MtCompletionTest`.

## Questions for the owner

1. **Narrowing.** A selector's list shows only values that select at least one test given the other selectors on
   the line, and `-TestId` only the tests those selectors leave. Recommended, because the selectors combine with
   AND and anything else would select nothing. The alternative is to always show every value.
2. **Aliases.** Insert the key (`exchange`) when the user types an alias (`exo`), rather than offer the alias as a
   value of its own. Recommended: one value per product, and the key is what results and reports show.
3. **No result cap.** Unlike ZeroTrustAssessment's 10 plus `...`. Recommended.
4. **Preview and long-running tests** stay in `-TestId` completion, marked in the tooltip, because naming one by its
   exact ID runs it.
5. **Folder**: `internal/engine/completion/`, or `internal/session/`.
6. **Scope of the first pull request**: steps 1 to 3 together, or 1 and 2 first.

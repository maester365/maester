# AGENTS.md

Maester is a PowerShell framework for monitoring Microsoft 365 security
configuration, with its own test engine. Pester is used only for the module's unit tests
and to run users' Pester-format custom tests. Requires PowerShell 7.4+. Monorepo: `powershell/` (module source),
`tests/` (security checks shipped to users), `src/Maester.Engine/` (C# engine core,
built DLL committed in `powershell/lib/`), `build/`, `website/` (Docusaurus,
maester.dev), `report/` (React app that builds the HTML report template).

## Two unrelated test trees — don't mix them

- `tests/` — Maester **security checks** that ship to end-user tenants, run via
  `Invoke-Maester`. Each check is a native test: `tests/<suite>/[<service>/]Test.<ID>.ps1`
  (one function with a `[MaesterTest(...)]` attribute) plus `Test.<ID>.md`. No
  `*.Tests.ps1` wrappers, no connection/licence guards, no outer try/catch: declare
  `Service`/`License` and the engine handles them. Scaffold with `New-MtTest`,
  validate with `Get-MtTest <ID>` (`Get-MtTest -Path` applies the rules of a custom test
  and does not report a missing attribute), run with `Invoke-MtTest -Path`; `Convert-MtTest`
  converts users' Pester-format tests. New MT.xxxx checks go here; follow
  `.github/skills/maester-test-expert/SKILL.md` and `website/docs/writing-tests/index.mdx`,
  and choose the attribute values with `website/docs/writing-tests/attribute-rubric.md`
  (see "Reviewing a test's attributes" below). A benchmark test for a requirement that another
  suite already checks is a shim that returns that test's result (see "Reviewing a test for
  duplicates" below).
- `powershell/tests/` — **unit tests for the module itself**.

## Commands

- Unit tests: `./powershell/tests/pester.ps1` — run before pushing. These enforce
  naming, exports, help, and PSScriptAnalyzer conventions; fix what they flag.
- Build module: `./build/Build-MaesterModule.ps1`; validate: `./build/Test-MaesterModuleOutput.ps1`
- Website: `cd website && npm ci && npm start` · Report: `cd report && npm ci && npm run build`

## Hard rules

- Generated content — regenerate, never hand-edit: `website/docs/commands/`,
  `website/docs/tests/`, `website/versioned_docs/`, everything under
  `powershell/internal/generated/`, and the native `tests/eidsca/Test.EIDSCA.*` and
  `tests/orca/Test.ORCA.*` files the generators in `build/eidsca/` and `build/orca/`
  write. Edit the PowerShell source, comment-based help or generator templates and let
  automation regenerate. `powershell/assets/ConsoleContributors.json` (the dashboard's
  Featured contributor list) is written by `./build/Update-ConsoleContributors.ps1` from
  the website's contributor data.
- A test is mapped to a framework in one place: the `Control` attribute, `<framework-key>:<requirement-id>`. A
  CIS test carries `Control = 'cis-m365:5.1.5.1'`, a CISA test `Control = 'cisa-scuba:MS.AAD.3.1'`, and any other
  test may name the same requirements. An ASD test carries `Control = 'essential-eight:ISM-1504'` (or `ism:<id>` for a
  control outside the maturity model). Every test in `tests/cis`, `tests/cisa` and `tests/asd` must name a requirement of its
  suite's framework. The engine builds `Benchmark` from the first `Control` that a framework file knows and adds
  that requirement's `Related` references to `Control`; do not repeat those, and do not add benchmark tags.
- A framework file is a catalogue, not a list of tests: `tests/<suite>/frameworks/<key>.json`
  (`tests/cis/frameworks/cis-m365.json`, `tests/cis/frameworks/cis-github.json`,
  `tests/cisa/frameworks/cisa-scuba.json`, and the generated `tests/asd/frameworks/essential-eight.json` and
  `tests/asd/frameworks/ism.json`, written by `build/asd/Update-AsdFramework.ps1` from the ISM OSCAL release),
  declared in the suite's `suite.json` (`Frameworks`: `Key`,
  `Version`). It holds the framework's name and version and each requirement's `Id` and facts (CIS `Level` and
  `Profile`; CISA `Criticality`, `Upstream` and `Related` NIST references; Essential Eight `Level` and `Strategy`;
  ISM `Guideline`, `Section` and `Applicability`), never the text of a benchmark and
  never a `Tests` list. When a new test implements a requirement the file does not have, add the requirement in
  the same commit, or `./build/Build-MaesterModule.ps1` and the unit tests fail.
- Checks read through the session cache. A run reports on one snapshot of the tenant, so no check, pack or helper
  passes `-DisableCache` or otherwise bypasses the Graph or GitHub cache, even to read data that changed during the
  session. Only the transport helpers listed in `powershell/tests/general/GraphCacheUsage.Tests.ps1` may offer the
  switch, and that test fails on any other use. Don't apply a review suggestion to bypass the cache.

## Repository layout — where files go

Full rules and reasoning: `website/docs/contributing.md` ("Repository layout"), published at
https://maester.dev/docs/next/contributing#repository-layout. `powershell/tests/general/RepositoryLayout.Tests.ps1`
enforces them. When writing or reviewing a change, check every added, moved or renamed file:

- Folder names under `tests/`, `powershell/` and `build/` are lowercase kebab-case
  (`global-secure-access`, not `GlobalSecureAccess`). No two paths may differ only in case.
- One name per service, the same everywhere: `ad`, `azure`, `azure-devops`, `copilot`,
  `copilot-studio`, `defender`, `entra`, `exchange`, `fabric`, `foundry`, `github`,
  `global-secure-access`, `graph`, `intune`, `purview`, `sharepoint`, `teams`, `xspm`.
  Folders name the product whose settings a check reads, never a theme: an AI check goes in
  the folder of its product (an Entra agent identity check in `entra/`) and declares
  `Area = 'ai'`. A new service must be added to the guide and the test.
- `tests/<suite>/` holds only `Test.<ID>.ps1`, `Test.<ID>.md`, `suite.json` and `README.md`, plus the suite's
  framework files, `frameworks/<key>.json` beside its `suite.json` (lowercase key; nothing else goes in a
  `frameworks/` folder).
  Suites: `maester/<service>/` (plus `drift/`; `maester/xspm/` has its own suite.json),
  `cis/`, `cisa/<service>/`, `asd/<service>/`, `ad/<area>/`, generated `eidsca/` and `orca/`, and `custom/`
  (reserved for users; never commit tests there).
- `powershell/public/` (exported) is grouped by job: `run/`, `connect/`, `report/`, `app/`,
  `packs/`, `services/<service>/`. `powershell/internal/` uses `engine/`, `session/`, `connect/`,
  `report/`, `app/`, `packs/`, `services/<service>/`, `checks/<suite>/<service>/`, `generated/`,
  `utility/`. Nothing sits directly in `public/` or `internal/`.
- `packs/<name>/` at the repository root holds the Maester Packs that ship with Maester (ID `maester.<name>`,
  a code of the pack's own such as `ZTA`, test IDs `<Code>.<n>` without the `MP.` that installed packs use). They are not under `tests/`: a pack loads into its own private
  module, and its rows carry `Source = Custom` and `Package`. See `packs/README.md`.
- Put a function by its job, not by the check that first needed it: reusable data access
  for a service goes in `internal/services/<service>/`; logic only one suite's checks use
  goes in `internal/checks/<suite>/<service>/`; a helper users call from custom tests goes
  in `public/services/<service>/` (and in the manifest's `FunctionsToExport`).
- One function per file, named `Verb-Noun.ps1` after the function, with an approved verb.
- Custom tests can call only exported commands. To make an internal helper available to them,
  `git mv` it from `internal/services/<service>/` to `public/services/<service>/`, add it to
  `FunctionsToExport`, and give it full comment-based help (see "Making an internal helper public"
  in the contributing guide). Exporting a command makes it public API; flag a promotion in review.

## Reviewing a test for duplicates

Benchmarks overlap, and a check that CIS, CISA, ASD and Maester each implement in their own way gives
two answers for one setting and drifts with every benchmark update. When you write, change or review a
test, look for a duplicate before the attribute review:

1. Find the tests in every suite that read the same setting (`Get-MtTest -Product <key> -Feature <key>`,
   and a search of `tests/` for the Graph endpoint or setting name).
2. If one exists, read what the benchmark asks in its own sources, not only the requirement's one-line
   text: its audit or assessment guidance and any reference configuration it publishes (for ASD, the
   ISM, the Essential Eight assessment process guide and the ASD Blueprint for Secure Cloud). Note
   every concrete value they name, and whether it differs from the existing test.
3. Decide, as "Tests that another suite already has" in `website/docs/writing-tests/index.mdx` says:
   - the benchmark asks for what the existing test checks: the new test is a shim, a test whose body is
     `return <the existing test's function>`, with its own `Id`, `Title`, `Control` and guide;
   - it asks for the same check with a different value the existing test takes as a parameter: a shim
     that passes the value;
   - it asks for something no test checks, or a rule no parameter covers: a test of its own, which
     reads data through `powershell/internal/services/<service>/` helpers instead of copying another
     test's logic.
4. Fail the review when a benchmark test re-implements a check another suite already has and the
   benchmark's sources give no reason, or when a helper named after a suite (`Get-MtAsd*`,
   `Get-MtCis*`) does data access that is not specific to that suite. Say which test it duplicates
   and which source you read.

`powershell/tests/general/TestShims.Tests.ps1` checks the mechanical part: a shim declares the same
attribute values as the test it calls (`Product` to `Mitre`, `Service`, `License` and the other gates),
calls a test that exists and is not a shim, passes only parameters that test declares, leaves its own
requirement off that test's `Control`, and names that test in its guide. Whether the benchmark asks for
the same thing is the reviewer's judgement.

## Reviewing a test's attributes

Every built-in test declares what it is about, how urgent a failure is and which attack techniques
it addresses: `Product`, `Feature`, `Area`, `ResourceType`, `Severity`, `UserImpact`,
`ImplementationCost`, `Mitre` and, where one applies, `RelatedProduct`. The rules for each value
are in `website/docs/writing-tests/attribute-rubric.md` (the rubric); the allowed keys are in
`powershell/assets/MaesterTaxonomy.psd1`.

When you write, change or review a test, check its attributes against the rubric as a separate
step, after the code review and before you approve or hand off:

1. Read the test's `.ps1` and `.md` and state in one sentence what it checks and what the fix is.
2. For each attribute that is new or changed, decide whether the declared value fits the rubric. A
   value fails only when the rubric clearly gives a different one; say which value and which rule.
3. Fail the review if any value does not fit. Do not approve with a note to fix it later.

Three things enforce this, in order:

- `powershell/tests/general/NativeTestAttributes.Tests.ps1` fails on anything mechanical: a missing
  attribute, a key that is not in the taxonomy, a retired ATT&CK technique, a taxonomy tag on a
  built-in test.
- The `attribute-review` workflow (`.github/workflows/attribute-review.yaml`) runs a reviewer model
  against the rubric on every pull request that adds a test or changes one of these attributes, and
  fails the check with the value it expected and the reason. It calls the Claude API with the
  `ANTHROPIC_API_KEY` secret; without the secret it reports that the review was skipped. To run
  the same review locally before pushing, set `ANTHROPIC_API_KEY` and run
  `./build/review/Invoke-MtAttributeReview.ps1 -BaseRef origin/main -OutputPath ./TestResults`
  (`TestResults/` is ignored by git; without `-OutputPath` the report is written to the current
  folder).
- The person or agent reviewing the pull request applies the same rubric and is the last word. A
  maintainer who disagrees with the workflow can apply the `attribute-review-override` label and
  should say why in the pull request.

## Labelling pull requests, issues and discussions

Labels follow one rubric so the queue can be filtered by status, type and product. The
labels are defined in `.github/labels.json`; the rules for choosing them are in
`.github/skills/maester-triage/SKILL.md`. To triage, use the `maester-triage` agent (or follow
the skill directly): it shows its plan before changing anything and only ever changes labels.
After editing `.github/labels.json`, run `./build/github/Sync-GitHubLabels.ps1` to see the
changes and `-Apply` to make them. `-Apply` creates, renames and updates labels and copies a merged
label onto the items that carry the old one; add `-DeleteMerged` to also delete the old labels.

## Agents and skills

The agents and skills in this repository are listed in `website/docs/agents-and-skills.md`. Each
has one source file: `.github/agents/<name>.agent.md` or `.github/skills/<name>/SKILL.md`. The
Claude Code copies under `.claude/agents/` and `.claude/skills/`, and that docs page, are generated
from them by `./build/github/Update-AgentFiles.ps1`. Edit the source file, run the script, and
commit both; never edit a generated copy. `powershell/tests/general/AgentFiles.Tests.ps1` fails
when they drift.

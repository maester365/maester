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
  (see "Reviewing a test's attributes" below).
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
  test may name the same requirements. Every test in `tests/cis` and `tests/cisa` must name a requirement of its
  suite's framework. The engine builds `Benchmark` from the first `Control` that a framework file knows and adds
  that requirement's `Related` references to `Control`; do not repeat those, and do not add benchmark tags.
- A framework file is a catalogue, not a list of tests: `tests/<suite>/frameworks/<key>.json`
  (`tests/cis/frameworks/cis-m365.json`, `tests/cis/frameworks/cis-github.json`,
  `tests/cisa/frameworks/cisa-scuba.json`), declared in the suite's `suite.json` (`Frameworks`: `Key`,
  `Version`). It holds the framework's name and version and each requirement's `Id` and facts (CIS `Level` and
  `Profile`; CISA `Criticality`, `Upstream` and `Related` NIST references), never the text of a benchmark and
  never a `Tests` list. When a new test implements a requirement the file does not have, add the requirement in
  the same commit, or `./build/Build-MaesterModule.ps1` and the unit tests fail.

## Repository layout — where files go

Full rules and reasoning: `website/docs/contributing.md` ("Repository layout"), published at
https://maester.dev/docs/next/contributing#repository-layout. `powershell/tests/general/RepositoryLayout.Tests.ps1`
enforces them. When writing or reviewing a change, check every added, moved or renamed file:

- Folder names under `tests/`, `powershell/` and `build/` are lowercase kebab-case
  (`global-secure-access`, not `GlobalSecureAccess`). No two paths may differ only in case.
- One name per service, the same everywhere: `ad`, `azure`, `azure-devops`, `copilot`,
  `copilot-studio`, `defender`, `entra`, `exchange`, `foundry`, `github`,
  `global-secure-access`, `graph`, `intune`, `purview`, `sharepoint`, `teams`, `xspm`.
  Folders name the product whose settings a check reads, never a theme: an AI check goes in
  the folder of its product (an Entra agent identity check in `entra/`) and declares
  `Area = 'ai'`. A new service must be added to the guide and the test.
- `tests/<suite>/` holds only `Test.<ID>.ps1`, `Test.<ID>.md`, `suite.json` and `README.md`, plus the suite's
  framework files, `frameworks/<key>.json` beside its `suite.json` (lowercase key; nothing else goes in a
  `frameworks/` folder).
  Suites: `maester/<service>/` (plus `drift/`; `maester/xspm/` has its own suite.json),
  `cis/`, `cisa/<service>/`, `ad/<area>/`, generated `eidsca/` and `orca/`, and `custom/`
  (reserved for users; never commit tests there).
- `powershell/public/` (exported) is grouped by job: `run/`, `connect/`, `report/`, `app/`,
  `packs/`, `services/<service>/`. `powershell/internal/` uses `engine/`, `session/`, `connect/`,
  `report/`, `app/`, `packs/`, `services/<service>/`, `checks/<suite>/<service>/`, `generated/`,
  `utility/`. Nothing sits directly in `public/` or `internal/`.
- `packs/<name>/` at the repository root holds the Maester Packs that ship with Maester (ID `maester.<name>`,
  a code of the pack's own such as `ZTA`, test IDs `MP.<Code>.<n>`). They are not under `tests/`: a pack loads into its own private
  module, and its rows carry `Source = Custom` and `Package`. See `packs/README.md`.
- `pack-registry/publishers/<publisher>.json` is the pack registry: a publisher's GUID, the GitHub accounts
  (login and numeric ID) that own it, and each pack's GUID, ID and code. `build/packs/Test-MtPackRegistry.ps1`
  (run by `PackRegistry.Tests.ps1`) fails on a GUID, pack ID, code or publisher that is not unique. A pack in
  `packs/` must be registered under `maester365.json` with the `Code` and `Guid` of its manifest.
- Put a function by its job, not by the check that first needed it: reusable data access
  for a service goes in `internal/services/<service>/`; logic only one suite's checks use
  goes in `internal/checks/<suite>/<service>/`; a helper users call from custom tests goes
  in `public/services/<service>/` (and in the manifest's `FunctionsToExport`).
- One function per file, named `Verb-Noun.ps1` after the function, with an approved verb.
- Custom tests can call only exported commands. To make an internal helper available to them,
  `git mv` it from `internal/services/<service>/` to `public/services/<service>/`, add it to
  `FunctionsToExport`, and give it full comment-based help (see "Making an internal helper public"
  in the contributing guide). Exporting a command makes it public API; flag a promotion in review.

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

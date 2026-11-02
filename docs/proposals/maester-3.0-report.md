# Maester 3.0 report redesign

Status: built in `report/` (overview, action plan, all tests, product, framework, ATT&CK, pack, changes and
run views; tabbed test detail; small-run layout; product icons; Copy for AI). The result data it needs is
implemented. Not yet built: accepted risk, co-branding and WebMCP.

- To see it: `npm --prefix report run dev`, then open `?sample=suite` (a full run), `?sample=tenants` (five
  tenants), `?sample=one` or `?sample=2x` (a 2.x result). The first design was a single-file mock, which this
  build replaces and which is not in the repository.

The mock used the report's 3.0 sample (`report/src/lib/testResults.ts`, the Pora Inc. tenant) plus
data it synthesises so every 3.0 feature has something to show: 336 Zero Trust Assessment rows from
the pack's real `catalog.json`, 13 ASD rows, a seven-test community pack (`MP.CNT`), reason codes on
skipped rows, and a previous run for drift. These are marked as synthetic in the build script and are
not tenant data.

## Who reads the report and what they need

| Reader | Question | Where the mock answers it |
| --- | --- | --- |
| Admin who has to fix things | What do I fix first, and how? | Overview "Fix these first", Action plan, test sheet with the fix and a rerun command |
| Security lead or manager | How are we doing, and is it getting better? | Overview headline, failed by severity, changes since last run |
| Auditor or GRC | Which framework requirements do we meet? | Frameworks views: requirements met, not met, not run, no test |
| Security analyst | Which attack techniques are we exposed to? | ATT&CK view |
| Product owner | How is my product doing? | Product views, grouped by feature |
| Whoever ran it | Why didn't some tests run? | "Why N tests did not run" with the command that fixes each group, Run details |

The 2.x report answers the first and last questions with one table. 3.0 gives every test the
attributes to answer the rest, and the report should use them.

## What 3.0 added, and where the report shows it

| 3.0 feature | Result fields | Report |
| --- | --- | --- |
| Products and features | `Product`, `RelatedProduct`, `Feature` + `Taxonomy` | Products in the sidebar with icons; product page grouped by feature; "Also affects" |
| Areas | `Area` | Security areas strip on the overview; group-by in the test list |
| Severity, user impact, effort | `Severity`, `UserImpact`, `ImplementationCost` | Ranking, effort/impact matrix, quick wins |
| Frameworks | `Benchmark`, `Control` + framework files | One view per framework, requirement coverage |
| ATT&CK | `Mitre` + `Taxonomy.Attack` | Tactic/technique grid, each tile coloured by its tests |
| Reason codes | `ReasonCode`, `ReasonDetail` | Grouped "did not run" list with a fix command; callout on the test |
| Maester Packs | `Source = Custom`, `Package` | Packs section in the sidebar, one view per pack, pack-defined grouping |
| Pack reports | `Attachments` (`Add-MtReportAttachment`) | Reports section, sandboxed frame (as today) |
| Families | `ParentId`, `InstanceId` | Instances list under the family in the test sheet (not in the mock yet) |
| Lifecycle | `Lifecycle`, `ReplacedBy` | Shown in the sheet; deprecated tests get a "replaced by" link |
| Licences, services, permissions | `License`, `Service`, `Permission`, `TenantContext` | Sheet attributes; Run details |
| Multi-tenant merge | `Tenants[]` / `Partitions[]` | All tenants page (`/tenants`), tenant list in the sidebar, switcher in the top bar, Tenants tab on a test |
| Affected objects | `AffectedObjects` | Kept as a Reports view (not in the mock; sample has none) |
| Drift suite, `Compare-MtTestResult` | `MT.1060` rows; compare output | "Changes since last run" view (needs the previous run, see below) |

## Information architecture

The sidebar is built from a view registry. Every page, built in or from a pack, is a view with an
id, a group, a title, an optional count and a render function. Groups, in order:

1. **Summary**: Overview, Action plan, All tests
2. **Products**: one view per product that has results, with its icon and failed count
3. **Frameworks**: CIS Microsoft 365, CISA SCuBA, Essential Eight, NIST SP 800-53 (and any framework a
   pack or custom test maps to)
4. **Threats**: MITRE ATT&CK
5. **Packs**: one view per pack in the run, plus "Add a pack to the next run"
6. **Reports**: Changes since last run, embedded reports from packs, Affected objects, Run details

A test opens in a side sheet from anywhere, so the reader never loses their place. Search (⌘K)
finds views, tests, controls and techniques. Each view has a plain `#id` link for sharing.

### Overview

Headline sentence with the pass rate (passed ÷ (passed + failed); Investigate, skipped and not run are
not scored), counts by result, changes since the last run, failed by severity, the six tests to fix
first, product cards, framework coverage, security areas, why tests did not run, and the packs in the
run.

### Ranking: "Fix these first"

```
priority = 4 × severity (Critical 4 … Info 0)
         + 1.5 × (3 − user impact)      Low 2, Medium 1, High 0
         + 1.5 × (3 − effort)           Low 2, Medium 1, High 0
         + 0.3 × ATT&CK techniques (max 3)
         + 0.2 × framework requirements
```

Severity dominates; within a severity, cheap fixes users won't notice come first. A failure with
Medium or higher severity, Low user impact and Low effort is labelled a quick win. The Action plan
shows the 3×3 effort/impact matrix; choosing a cell lists its tests.

Open: a benchmark shim and the test it calls report the same setting twice. The plan should show one
row per setting, with the frameworks of both. That needs the shim relationship in the result (see
data changes).

### Frameworks

A framework view counts requirements, not tests: a requirement is met when every test for it passes,
not met when any fails, and "no Maester test" when nothing maps to it. Filters follow each framework's
own facts (CIS L1/L2, CISA SHALL/SHOULD, Essential Eight ML1–ML3). Groups follow the framework's
structure (CIS sections, CISA services, Essential Eight strategies, NIST control families).

### Packs

A pack's view shows its publisher, version, badges (Official, Microsoft MVP, GitHub-verified org) and
risk level, its results, its own grouping (ZTA: pillar and category), and any report it embedded. A
pack's results count in the report, never as Maester's own checks. Product cards say how many of their
tests came from packs.

### Small runs

The report adapts to the size of the run instead of showing empty charts. A view registers with a
condition and is left out of the sidebar when it has nothing to show. The mock's "Mock sample" menu
switches between a full run (673 tests), one suite (`-Suite CIS`, 25 tests) and one test.

| Run | What the reader sees |
| --- | --- |
| 1 to 3 tests | The tests themselves: the title as the headline, the verdict and how it compares with the last run in one sentence, each test's full detail inline, and commands to check more (`-Feature`, `-Product`, `-Suite`, everything). The sidebar has only Result and Run details. |
| A handful to one suite | The usual overview. Sections with nothing to show are left out: no Packs without packs, no Products card grid for one product, only the frameworks the tests map to. |
| Full run | Everything. |

The product, framework, ATT&CK and change views stay out of the sidebar for 1 to 3 tests: the test's own
tabs show its product, frameworks, techniques and history.

### The test view

A test opens in a side sheet (or inline for a small run) with a fixed header and tabs, so a long guide
never pushes the metadata out of reach:

- **Header**: result, ID, pack, "was passed last run", title, and key facts as chips with icons (product
  with its logo, severity, user impact, effort, area); rerun command, Docs, Copy for AI.
- **Finding**: what an attacker could do (from the test's area, in plain words), the reason it didn't run if
  it didn't, what Maester found, and why it matters (the guide up to its remediation heading).
- **How to fix**: the guide's remediation section, then the command to check it again.
- **Details**: every attribute, grouped (what it checks, impact, how it runs, where it comes from), each with
  its own icon; "Same check as" and "Also reported as" for shims.
- **Frameworks** and **ATT&CK** with counts in the tab; **History** compares with the previous run.

Each attribute has one icon used everywhere it appears (sheet, details, filters), drawn as one stroke set in the
report so no icon library is needed.

## Data changes the report needs

All additive to schema 2.1. Items 1, 2, 3, 5 and 6 are implemented (see `website/docs/result-schema.md`);
item 4 is open.

1. **`Frameworks`** (top level, done): for each framework the rows map to, `Key`, `Name`, `Version`, `Url`,
   `Complete` and the requirements with their facts. Built by `Get-MtResultFramework` from the framework files
   that ship with Maester. A catalogue over 300 requirements (the ISM) and NIST SP 800-53 list only the
   requirements the rows name, with `Complete = false`. About 37 KB when every shipped framework is used.
   A framework declared by a custom suite has no entry yet.
2. **`Packs`** (top level, done): one entry per pack of the run that is not turned off: `Id`, `Code`, `Name`,
   `Description`, `Version`, `Publisher`, `BuiltIn`, `Homepage`, `Risk` (the accepted risk from the lock file),
   `Status`, `ReasonCode`, `Reason` (`Get-MtResultPack`). Badges (MVP, GitHub-verified org) are not known
   locally; the report shows "Official" for a built-in pack.
3. **`Fields` on instance rows** (done): a family's instance source can return `Fields`, a hashtable of names to
   strings or string arrays, written to the row. ZTA returns `Pillar` and `Category`. Generic rather than
   pack-only, so any family can use it.
4. **Pack rows use taxonomy products** (open): ZTA rows have `Product = 'Zero Trust Assessment'`; mapping pillars
   to products (Identity → Entra ID, Devices → Intune, Data → Purview, SecOps → Defender) would put them on the
   product pages. Open question in `zero-trust-assessment-pack.md` §6.
5. **`Previous`** (done): `Invoke-Maester` reads the newest earlier `TestResults-*.json` for the tenant in the
   output folder and writes `{ ExecutedAt, File, Results: { <Id>: <Result> } }` (`Get-MtPreviousResult`).
   About 20 KB for 700 tests. No switch to turn it off yet.
6. **`ShimOf`** (done): on a benchmark shim row, the test it returns (`Get-MtShimCommand` in the test reader,
   resolved in `Get-MtNativeTestInventory`). Four shims today, all ASD.

The mock's data uses the earlier names (`PackFields`, `Packs[].Badges`, `Packs[].GroupBy`); the real report
reads the fields above.

## Making views pluggable

Three levels, from safest to most powerful.

1. **Built-in views** register like any other view, so adding one is one file.
2. **Declarative pack views**: a pack manifest gets a `Report` key that the report renders itself:

   ```json
   "Report": {
     "GroupBy": [{ "Field": "PackFields.Pillar", "Name": "Pillar" }, { "Field": "PackFields.Category", "Name": "Category" }],
     "Summary": [{ "Title": "Pillars", "GroupBy": "PackFields.Pillar" }],
     "Embedded": [{ "Title": "Zero Trust Assessment report", "Setting": "ZeroTrustAssessment.EmbedReport" }]
   }
   ```

   No pack code runs in the report. This covers most of what a pack needs: its own grouping, summary
   cards and a link to its embedded report.
3. **Embedded reports** stay as they are: `Add-MtReportAttachment` puts the HTML in the file and the
   report shows it in a sandboxed frame with no access to the rest of the report or its data.

Running a pack's JavaScript inside the report's own page is not proposed: it would see every result
in the file and could change what the reader sees. If a pack needs a custom visual, it embeds a report.

Users' own views follow the declarative format: `maester-config.json` `Report.Views` names a filter
and a grouping (for example "Tier 0 hygiene": Area privileged-access, grouped by Feature), and the
report adds it to the sidebar. Other report types (a board summary, a framework attestation) become
views that the Export menu can also write as Markdown.

## Microsoft product icons

The mock now uses the icons from [msicons](https://github.com/DanielBradley1/msicons) (the source of
msicons.com, a community collection by Daniel Bradley, MVP). It has 8 of Maester's 14 products: Entra ID,
Defender, Intune, SharePoint, Teams, Azure, Azure DevOps and Copilot Studio. It has no Exchange, Purview,
Fabric, Microsoft 365, Active Directory or GitHub icon; those keep a neutral tile with their initials until
a source is found. Purview's and Microsoft 365's now come from Wikimedia Commons (by Microsoft) and Exchange's from Loryan Strant's
MicrosoftCloudLogos (a PNG; see the products README). The repository has no licence file, and msicons.com says the icons stay Microsoft's under
Microsoft's terms, so the terms below still apply. The eight minified SVGs are 51 KB as base64 data URIs
(base64, because the colours' `#` breaks a plain-text data URI).

Microsoft publishes official icons for Entra, Microsoft 365 and Azure products with the same terms:

> Microsoft permits the use of these icons in architectural diagrams, training materials, or documentation.

Their guidelines also say to keep the product name near the icon, not to crop, flip, rotate or distort
them, not to use them to represent your own product, and (Entra) not to use them in marketing.

- Sources: [Entra architecture icons](https://learn.microsoft.com/entra/architecture/architecture-icons),
  [Azure icons](https://learn.microsoft.com/azure/architecture/icons/) (Entra ID, Defender, Intune, Purview,
  Foundry), [Microsoft 365 icons](https://learn.microsoft.com/microsoft-365/solutions/architecture-icons-templates)
  (Exchange, SharePoint, Teams; this page is archived).
- A security report about a tenant reads as documentation, and the report uses each icon only beside the
  product's name, never as Maester's mark. That is a reasonable reading, not an explicit grant: get a
  written OK from Microsoft before shipping, and keep the icons out of maester.dev marketing pages.
- Use the SVGs unchanged (no recolouring for dark mode; put them on a light tile in dark mode if needed).
- Size: one optimised SVG per product, about 2–4 KB each, 30–50 KB for the 14 products. Store them once in
  `powershell/assets/product-icons/` with the source and date, and inline only the icons the run uses.
- GitHub publishes its own logo guidelines; check them before using its mark. Azure DevOps is in the Azure set;
  I did not find a current Active Directory icon, so it may keep a neutral tile.

The mock uses neutral two-letter tiles in the icon slot. No Microsoft artwork was downloaded.

**Feature icons (built).** Each of the taxonomy's 104 features has an msicons icon, shown beside the feature's
name on product pages, in the test list's Feature filter and group headings, and in a test's header: Azure
service icons where one exists (Conditional Access, PIM, ID Protection, Intune's device icons) and Microsoft's
blue icon set for the rest (mail, key, globe). 78 files, 105 KB minified; `website/static/report-icons/v1/features/README.md`
lists the source of each and `report/src/lib/featureIcons.ts` maps the features to them.

**Loaded from maester.dev (built).** The product and feature icons are not embedded: the report loads them from
`https://maester.dev/report-icons/v1/`, with no referrer. Offline, products show their initials tile and features no
icon. The files under `v1` never change, so old reports keep working; a new icon set goes in `v2`. The Astro rebuild of
maester.dev must serve the same paths (copy `website/static/report-icons` into its `public/`).

**Assistant icons.** The Ask AI menu shows Claude's, ChatGPT's and Microsoft 365 Copilot's marks
(`report/src/assets/ai-icons/README.md`). OpenAI's brand rules were not checked; simple-icons no longer ships
OpenAI's logo.

## Size and dependencies

Today `powershell/assets/ReportTemplate.html` is 404 KB before any data. It bundles Preact, Tailwind,
`marked`, DOMPurify and three icon libraries (Heroicons, Remix Icon and Lucide).

| Part | Plan | Budget |
| --- | --- | --- |
| Framework | Keep Preact (React-compatible, ~4 KB) | 15 KB |
| CSS | Keep Tailwind, generated at build | 25 KB |
| Markdown | Keep `marked` + DOMPurify: test results contain tenant text, so sanitising stays | 55 KB |
| Icons | One set (Lucide), tree-shaken; drop Heroicons and Remix Icon | 10 KB |
| Charts | Hand-written SVG (ring, bars, matrix, grid); no chart library | 0 |
| Product icons | Official SVGs, only those the run uses | ≤ 50 KB |
| Fonts | System font stack; no web font in the report (it is often opened offline) | 0 |
| Views and app code | | 60 KB |
| Product and feature icons | Loaded from maester.dev, not embedded | 0 |
| **Template total** | | **467 KB as built** (410 KB before), with the overview's headline cards, trend, posture grid, outcome tabs and checked objects |

As built, Heroicons, Remix Icon and the Tailwind typography plugin are gone and the new views add about as
much code as the old home page removed; the growth is the icons. Reaching about 250 KB needs the older pages
(config, system, affected objects, exports) moved off Tailwind onto the report's own stylesheet. Data is extra and
the same as today (about 1 MB for this sample, mostly `TestDescription` and `TestResult` markdown);
`Get-MtHtmlReport` could gzip it like attachments if it grows.

## Ideas taken into the design

Taken into the mock:

- **The score you could reach**: the headline says what the pass rate would be after fixing the
  high-severity failures.
- **What an attacker could do**: the overview groups results by attacker outcome (sign in as your users,
  take over an admin, get in through apps and guests, phish and hide in mail, take data out, work through
  devices, go unnoticed, exploit weak foundations), built from each test's `Area`. Each failed test opens
  with that sentence.
- **Severity in plain words**: each severity in the overview says what it means, from the attribute rubric.
- **Info is never scored**, as the rubric says; the pass rate leaves it out.

Ideas for later, not in the mock:

- **Accepted risk** as its own status that stays visible and counted, read from an exceptions file with who
  accepted it and when. The engine has no accepted risk in 3.0; this would be a report-side or config feature.
- **Fix in the portal or in PowerShell**, so the action plan can split work by who does it. Needs a field
  on the test or a convention in the guide.
- **Overview additions (built):** headline cards with chips that open the tests
  behind each number; the pass rate over the last ten runs (`Previous.History`, read from the start of each earlier
  result file); a compliance posture grid of frameworks by attacker outcome with each framework's change since the
  previous run; the attacker outcomes as tabs with what is open, what was fixed and which products; and the objects
  the tests named, by type, from `AffectedObjects`.
- **Multi-tenant rollup** for `Merge-MtMaesterResult` (built): a report of several tenants opens on All tenants,
  with each tenant's pass rate, failures, critical and high failures and change since its last run; each
  product and framework in each tenant as a heat grid; the tests that fail in most tenants (fix once, roll out
  everywhere) and those that fail in one tenant only; and a warning when a run is a week older than the others
  or a tenant did not connect to a service the others did. Every cell opens that tenant's own view, and a
  test's Tenants tab shows its result in each tenant. Ask AI copies a summary across tenants from this page.
- **Co-branding** for MSPs (logo and colour) and a print stylesheet for QBRs and audits.

Not taken: anything that needs a human SOC or write access (approve buttons, one-click remediation),
AI-written narratives (Maester's text stays the test's own guide), one blended score across frameworks, and
dismissals that hide a finding.

## Design language

The report follows the maester.dev redesign proposal so the site, the report and maester.cloud read as
one family: zinc neutrals, one accent (Ember `#D22C31`, `#FF6B6F` in dark mode) for the current page
and links, near-black buttons, red/orange/amber/green only for results and severity, test IDs, commands
and paths in a monospace face, the flame mark, light and dark themes. The mock loads Inter and Geist
Mono for the preview; the report itself uses the system stack.

## Letting an assistant reason over the report

The mock has "Ask AI" and "Copy for AI" buttons that copy a Markdown summary, every failure with its
guidance, or one test. That works today with any assistant.

Exposing the data through WebMCP so a browser agent can query it directly is being researched in a
separate session (`report/docs/webmcp-research.md` when it lands). Whatever it recommends should be off
by default and turned on by the reader, because the report holds tenant configuration.

## Decisions for Merill

1. Data item 4 (ZTA rows on taxonomy products), and whether `Previous` needs an off switch.
2. Whether pack results count in the headline pass rate (the mock counts them; ZTA doc §6 is open).
3. Pass rate excludes Investigate (the mock does).
4. Declarative pack views only, no pack JavaScript in the report.
5. Product icons: msicons for the 8 products it has, and a source for the other 6.
6. Drop two of the three icon libraries and web fonts.

## Implementation plan

1. ~~Result additions (`Frameworks`, `Packs`, `Fields`, `Previous`, `ShimOf`), with unit tests and
   `website/docs/result-schema.md`.~~ Done.
2. View registry and shell in `report/` (sidebar, router, sheet, search), keeping the 2.x routes as redirects.
3. Overview and Action plan.
4. Product, Framework, ATT&CK views.
5. Pack views and the manifest `Report` key (`website/docs/packs/writing-a-pack.md`, `Test-MtPack` validation).
6. Product icons, after the icon decision.
7. Remove the extra icon libraries; check the size budget in `build/Test-MaesterModuleOutput.ps1`.
8. The 2.x sample (`?sample=2x`) must still render: views that need 3.0 attributes hide when the data has none.

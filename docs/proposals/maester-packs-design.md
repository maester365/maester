# Design: Maester Packs (third-party test packs and connectors)

> **Status: DRAFT for owner review. Nothing is implemented.** Drafted 2026-10-07 on
> top of the Maester 3.0 design ([maester-3.0-design.md](maester-3.0-design.md),
> section 12.2 fixed the package seams that 3.0 ships). Owner rulings of 2026-10-07
> are applied: the names (*pack*, *Maester Packs*), the domain (packs.maester.dev),
> hosting on Cloudflare with GitHub Actions doing the indexing and scanning, compiled
> code allowed behind a High risk level, packs running in-process in v1, no publisher
> verification programme in v1, the recommendations of section 14, and every finding
> of the design review of 2026-10-07. This document supersedes 3.0 section 12.2, which
> still names `maester-package.json` and a pull-request registry. Section 14 lists what
> is still open; section 15 lists what is not yet verified.

## 1. Summary

Anyone can publish Maester checks for any platform from their own GitHub repository.
Users find them on **Maester Packs** at packs.maester.dev, install them with one
command, connect to the platform through `Connect-Maester`, and see the results in the
same report as the built-in checks. A pack is listed the way skills.sh lists an agent
skill: nobody submits anything; a public repository appears once people install from
it, and its page is built from the repository itself.

The design in one page:

- **A pack is a Git repository** (or a folder in one) with a `maester-pack.json`
  manifest, one or more 3.0 test suites (the same `Test.<ID>.ps1` + `.md` files and
  `suite.json` the built-ins use), and optionally a **connector**: the code that signs
  in to a platform Maester does not know about, such as Google Workspace or Okta.
  Pack test IDs are `MP.<code>.<number>` (`MP.CNT.0001`), where the code belongs to
  the publisher, the GitHub user or organisation, and is claimed the first time one of
  its repositories is indexed. Section 4.
- **Install from GitHub, pinned.** `Install-MtPack contoso/maester-google-workspace`
  resolves the latest release to a commit, downloads it, validates it without running
  any of it, shows its risk level and what it reaches, and asks for approval. It
  records the pack in `maester-config.json` and pins the commit, content digest and
  GitHub repository ID in `maester-packs.lock.json`. CI restores from the lock file, so
  what runs in CI is what someone reviewed in a pull request. Section 5.
- **Connectors plug into `Connect-Maester`.** A pack declares a service name and a
  few functions (connect, test, disconnect, describe, renew). `Connect-Maester
  -Service GoogleWorkspace` calls the pack's connect function, the 3.0 service gate
  uses its test function, and `Get-MtTenantContext`, the report and
  `Disconnect-Maester` use the rest. Pack code is written once and runs unchanged if
  packs are isolated later. Section 6.
- **Discovery like skills.sh, hosted cheaply.** An install sends an anonymous event to
  a small Cloudflare Worker. GitHub Actions in a public index repository (free
  minutes) fetch the repository themselves, validate and scan it, give it a risk level
  and publish the listing. The site and the index are static files on Cloudflare
  (free, unlimited requests); the Worker only takes install events and serves counts.
  Expected cost: nothing at launch, US$5 a month once traffic passes the free tier.
  Section 7.
- **The site, packs.maester.dev:** a leaderboard with search and filters, a page per
  pack (overview, tests, connector, security, versions), publisher pages and a
  publishing guide. Section 8 and the mockup canvas.
- **Security is designed in, because packs run with admin tokens.** No code runs at
  install. Every version is pinned to a commit that must belong to the named
  repository, and every path that loads pack code checks its digest and the blocklist
  first. Updates are explicit, a new release waits out a 72-hour cooldown, and a pack
  that reaches more needs new approval. Pack results are shown apart from the built-in
  checks and can never pass as them. Every version is scanned and given a **risk level**: Low (text
  only, clean), Medium (findings to read), High (compiled code or anything that cannot
  be scanned: install only if you trust the publisher), or Blocked. **Badges** say who
  published it: Official, Microsoft MVP, GitHub-verified organisation. A signed
  blocklist stops a malicious pack on every machine at its next run, and organisations
  can cap the risk level they allow. In v1 packs run in-process, like custom tests, and
  the prompt says so plainly; isolation in containers is a later phase. Section 9.
- **Phased.** Phase 1 ships the pack format, GitHub install, the lock file, connectors
  and publisher tooling. Phase 2 launches Maester Packs on Cloudflare. Phase 3 adds
  isolation and a publisher verification programme. Section 12.

## 2. Names and domain

**Decided:** one installable unit is a **pack** (`Install-MtPack`,
`maester-pack.json`); the marketplace is **Maester Packs** at
**packs.maester.dev**. Considered and not chosen: plugin, extension, link (the
maester's-chain lore), collection, and suite (taken by 3.0's `suite.json`).

### 2.1 packs.maester.dev or maesterpacks.com

| | packs.maester.dev (recommended) | maesterpacks.com |
| --- | --- | --- |
| Trust | Inherits maester.dev; users already know it. The install prompt, the CLI's endpoints and the docs all sit under one name | A second name to learn; every look-alike (`maester-packs.com`, `maesterpack.com`) becomes a phishing domain to watch |
| Cost and setup | Nothing to buy: maester.dev's DNS is already on Cloudflare, so the Worker gets a custom domain in the same zone | A domain to buy, renew, protect (registrar lock, DNSSEC) and add to Cloudflare |
| Isolation from maester.dev | A separate origin, so scripts on one cannot read the other. It is the same *site* for cookies: keep maester.dev free of cookies scoped to `.maester.dev` (it has none today) | Fully separate |
| Brand | "Maester Packs, part of Maester" | Room to stand alone later |

packs.maester.dev is the better choice: it costs nothing and keeps the trust in one
name. The site, the index files and the API all live under it (`/api/v1/...`), so the
browser and the CLI talk to one origin. Registering maesterpacks.com only to redirect
it, so nobody else can, is a cheap optional extra.

## 3. What skills.sh does, and what we copy

Checked on 2026-10-07 against the open-source CLI
([vercel-labs/skills](https://github.com/vercel-labs/skills), commit `958f4b7`) and the
site's own documentation.

**How it works.** There is no submission step. When someone runs `npx skills add
owner/repo`, the CLI sends an anonymous event to skills.sh with the source, the skills
installed, the install URL, the CLI version and whether it ran in CI. The site lists
whatever it hears about. Before sending, the CLI asks the GitHub API anonymously
whether the repository is public and sends nothing when it is private or unknown. The
server deduplicates hourly using a hash of the IP address and TLS fingerprint, then
discards it. `DISABLE_TELEMETRY` or `DO_NOT_TRACK` turns it off. No minimum is
documented; a skill with one install had its own page. Security audits from partner
scanners (Gen Agent Trust Hub, Socket, Snyk) run a few minutes after the first install
and show pass, warn or fail on the skill's page and before install. Skills flagged
malicious are hidden from the leaderboard and search; the CLI warns but never blocks.

**The site.** A leaderboard with All Time, Trending (24h) and Hot tabs (rank, skill,
owner/repo, an 8-week activity sparkline, installs); a page per skill at
`/{owner}/{repo}/{skill}` with the install command, the rendered `SKILL.md`, weekly
installs, GitHub stars, first seen, related skills and the audit results; pages per
repository and owner; `/official`, topic and agent pages; a README badge; a fuzzy
search API that the CLI's `find` command calls.

**What 2026 taught.** On skills.sh a typosquatted credential stealer reached #8 on
Trending with 1.7 million (non-unique) installs before it was reported and removed
within 12 hours (Zenity, August). Trail of Bits got past all three skills.sh scanners
with compiled Python bytecode and prompt injection (June). On ClawHub, 341 of 2,857
skills were malicious, behind a bar of "a GitHub account a week old" (Koi,
February). The research also found a one-install skill listed under a famous
repository's name and star count whose install command pointed at a bare IP address:
the source in the install event is whatever the client says, and the listing trusted
it.

| | skills.sh | Maester packs | Why |
| --- | --- | --- | --- |
| How a listing starts | Install event from the CLI; no submission | **Same** | The model you asked for: push to GitHub, install, listed |
| Private repositories | Anonymous GitHub check; nothing sent unless public | **Same**, and GitHub only at first, so no other-host gap | A private pack must never leak its name |
| Opt-out | `DISABLE_TELEMETRY`, `DO_NOT_TRACK` | **Same**, plus `MAESTER_TELEMETRY_OPTOUT` and config | Consistency with the ecosystem |
| Threshold | None observed | List on first install, **but only after our own fetch, validation and scans pass**; "New" label for 14 days | Fast for publishers without listing unscanned code |
| Trust in the event | The client's source and install URL are shown | **Never trusted**: the indexer fetches the stated repository at the stated commit itself and lists only what it fetched | Closes the namespace-spoofing hole observed above |
| Package format | `SKILL.md` frontmatter; many folders scanned | One `maester-pack.json`; fixed layout | A manifest is easier to validate and to show in a security prompt |
| Pinning | `#ref`; the lock file stores a content hash but not the commit | Commit, content digest and GitHub repository ID, checked on every load | Packs run with admin tokens |
| Updates | `skills update` reinstalls what changed | Explicit, diffed, re-approval when a pack reaches more | No silent code changes |
| Scanning | Partner audits (pass, warn, fail); advisory only | Scans on every version, a **risk level** on every version, and a **signed blocklist the client enforces** | A warning is not enough for code that runs unattended in CI |
| Ranking | Deduplicated installs | Same, and **popularity never changes trust**: risk levels come from scans, badges from GitHub and the MVP directory | Installs are gameable (the typosquat above) |
| Execution | The agent decides | In-process in v1, like custom tests; containers later | Section 9.4 |
| Site | Leaderboard, skill, repository and owner pages, official list, audits, badge | **Same structure**, plus Tests, Connector and Security tabs, risk levels and badges | Section 8 |

### 3.1 What other ecosystems add

- **Steampipe and Powerpipe** are the closest analog: *plugins* hold API access and
  credentials, *mods* are text-only benchmark packs installed from Git that declare
  `require { plugin "azuread" { min_version = "1.9.0" } }`, and connection settings live
  in config files with environment-variable and vendor-CLI fallbacks. We copy the split
  as an option (a connector pack that many test packs depend on, section 4.2) and the
  settings resolution (section 6.2).
- **Terraform Registry** discovers provider releases through a webhook on release tags,
  signs every release, has Official, Partner and Community tiers, and pins hashes in a
  committed lock file that fails `init` on a mismatch. We copy the tiers and the lock
  file behaviour.
- **VS Code Marketplace** blocks name-squatting of official publishers, verifies
  publishers by domain plus six months in good standing, and keeps a blocklist that
  uninstalls malicious extensions from users' machines. Its kill switch once removed a
  legitimate theme by mistake for two weeks. We copy the blocklist but **stop a pack
  from running instead of deleting it**, so a false positive is undone by removing the
  entry.
- **npm and GitHub** offer signed build provenance (Sigstore), trusted publishing and
  immutable releases. **ChainDrop** (August 2026) showed their limit: a hijacked
  maintainer account pushed tags, and the projects' own workflows published 444
  packages with valid provenance. Provenance proves where a release was built, not that
  its owner meant to release it. The fix the responders recommended, a release-age
  cooldown, is in section 5.4.
- **Trivy** (March 2026): 75 of 76 tags of a popular action were force-pushed to a
  secret stealer. Commit pins held where tag pins did not; packs are always pinned to
  commits.
- **PowerShell itself:** Microsoft treats only App Control-enforced Constrained
  Language Mode as a security boundary; a child process running as the same user,
  runspaces, execution policy and manually set CLM are not. .NET's guidance is to use
  separate processes, containers or OS users. Section 9.4 is written to that standard.

## 4. The pack

### 4.1 Layout

```text
maester-google-workspace/            (a GitHub repository)
  maester-pack.json                  the manifest
  README.md                          shown on the marketplace page
  LICENSE
  icon.svg                           optional, shown on the marketplace page
  connectors/
    GoogleWorkspace.ps1              the connector (section 6)
  tests/
    suite.json                       a 3.0 suite: tags, category, help URL template
    Test.MP.CNT.0001.ps1
    Test.MP.CNT.0001.md
    admin/
      Test.MP.CNT.0101.ps1
      Test.MP.CNT.0101.md
  helpers/
    Invoke-GwsRequest.ps1            functions the tests and the connector share
  .github/workflows/pack-scan.yml    optional: runs the index's scanners on every push (section 9.6)
```

A repository can hold several packs, each in its own folder with its own manifest, the
way a skills repository holds several skills. They are addressed as
`owner/repo/<folder>`.

### 4.2 The manifest

`maester-pack.json` is `suite.json` grown with the package fields that 3.0 section 12.2
fixed. Everything is static data; nothing in it runs.

```json
{
  "$schema": "https://maester.dev/schemas/maester-pack-1.0.json",
  "Id": "contoso.google-workspace",
  "Name": "Google Workspace security baseline",
  "Description": "CISA SCuBA-aligned checks for Google Workspace admin settings.",
  "Version": "1.2.0",
  "Publisher": "contoso",
  "License": "MIT",
  "Homepage": "https://github.com/contoso/maester-google-workspace",
  "Support": "https://github.com/contoso/maester-google-workspace/issues",
  "SecurityContact": "security@contoso.com",
  "RequiresMaester": ">=3.1 <4.0",
  "Code": "CNT",
  "Suites": ["tests"],
  "Helpers": ["helpers"],
  "Connectors": [
    {
      "Service": "CNT.GoogleWorkspace",
      "Platform": "GoogleWorkspace",
      "DisplayName": "Google Workspace",
      "File": "connectors/GoogleWorkspace.ps1",
      "Connect": "Connect-GwsService",
      "Test": "Test-GwsService",
      "Disconnect": "Disconnect-GwsService",
      "Describe": "Get-GwsServiceContext",
      "OptIn": true
    }
  ],
  "Uses": {
    "Services": ["CNT.GoogleWorkspace"],
    "GraphScopes": [],
    "TenantWrites": [],
    "Network": ["admin.googleapis.com", "oauth2.googleapis.com", "www.googleapis.com"],
    "Modules": []
  },
  "Categories": ["Google Workspace", "Identity", "Email"]
}
```

- **`Id`** is `<publisher>.<name>`, lower case. `Publisher` must match the GitHub owner
  for a listed pack (section 9.2). `maester` and `maester365` are reserved for official
  packs. Underneath the readable names, the index, the lock file and organisation
  policy key everything to GitHub's numeric owner and repository IDs, so a renamed
  owner keeps its packs (the old `Id` stays as an alias) and someone who re-registers a
  deleted name inherits nothing. A repository that moves to another owner gets the new
  owner's `Id` and `Publisher`, and every installer approves it again (section 5.4).
- **`SecurityContact`** is where reports about the pack go; the publisher page shows
  it, and a listed pack must have one.
- **`Code`** is the publisher's code, two to five letters or digits, held by the GitHub
  user or organisation that owns the repository. Every test ID in the pack is
  `MP.<Code>.<number>`, for example `MP.CNT.0001` (section 4.5).
- **`Uses`** declares what the pack reaches: the services its tests list, extra
  Microsoft Graph scopes and any tenant writes (section 6.6), network hosts outside the
  declared services, and PowerShell Gallery modules. It drives the install prompt, the scans (anything the code reaches
  that is not declared fails validation) and, once packs can be isolated, what a
  pack's container gets (section 9.4).
- **`Uses.Modules`** pins PowerShell Gallery modules by exact version, for example a
  Google API client. They are saved with `Save-PSResource -Version` into the pack store,
  not the user's module folder, so they never shadow the modules Maester itself loads,
  and they are imported by path. Saving runs nothing. The lock file pins the whole
  dependency closure, every module and version with its package hash, and restore
  checks them, because outside AllSigned PowerShell does not check a module's signature
  when it loads it. A module is rated like any other content (section 9.6): one that
  ships compiled code makes the pack High risk. Modules whose assemblies conflict with
  the Microsoft Graph, Exchange Online or Az modules are flagged by the scans.
- **`Requires`** names other packs this one needs, by source, `Id` and version range,
  most often a **connector pack**:

  ```json
  "Requires": { "Packs": [ { "Source": "contoso/maester-gws-connector",
                             "Id": "contoso.gws-connector", "Version": ">=1.0 <2.0" } ] }
  ```

  A pack can ship its own connector, as above, or depend on one, as Powerpipe mods
  depend on Steampipe plugins. The split is recommended when several test packs target
  one platform: one connector, one sign-in, one service name, reviewed once.
  - A connector pack lists in `Exports` the helper functions it shares (for example
    `Invoke-GwsRequest`). A pack that requires it can call those functions and read the
    connection state of the services it declares in `Uses.Services`, and nothing else
    of the connector pack.
  - `Source` lets phase 1, which has no index, find the required pack; the index checks
    that `Source` and `Id` agree.
  - `Install-MtPack` installs required packs with their own prompts, and the lock file
    records the whole dependency closure, each pinned like a top-level pack. A project
    has one version of each pack: ranges that cannot all be met are an install error
    naming the packs, and cycles are refused. `Uninstall-MtPack` refuses to remove a
    pack another installed pack requires, unless both go.
- **`Listed: false`** keeps a public pack out of Maester Packs entirely; installing it
  directly still works (section 9.10).
- **Unknown keys:** an unknown top-level key is ignored with a warning, as for
  `suite.json`. An unknown key inside `Uses`, `Connectors`, `Requires` or `Permissions`
  makes this Maester refuse the pack, because those keys describe what the pack can
  reach, and an older client that ignored one would leave it out of the install prompt.
- **`RequiresMaester`** accepts a version range. An older Maester gives each test a
  `RequiresNewerMaester` row, as in 3.0; a Maester newer than the range warns, and the
  index marks the pack as untested with that version (section 4.7).

### 4.3 What a pack may contain

Anything a GitHub repository can hold, including proprietary code under any licence.
What a pack contains sets its **risk level** (section 9.6) rather than whether it can
be listed. Validation rules, which a listed pack must pass:

- **Every `.ps1` and `.psm1` holds only function definitions** at the top level, as 3.0
  native tests do. No `using module`, `using assembly`, `#Requires -Modules` that loads
  something, class definitions, or top-level statements, because each of those runs
  code when a file is loaded rather than when a test is called. Libraries, including
  compiled ones, are loaded from inside functions at run time.
- Test files follow every 3.0 rule (attribute read from the AST, `.md` pairing,
  `Service` names that are built-in services or connectors the pack ships or requires).
- Every service, network host, Graph scope and Gallery module the scannable code
  reaches is declared in `Uses`. Undeclared reach in code we can read is a validation
  failure: the publisher declares it, or the version is not listed.
- No symbolic links, no paths that differ only in case (they unpack differently on
  Windows, macOS and Linux and would make the digest ambiguous), at most 50 MB per pack
  and 20 MB per file.

**Compiled and unscannable content** (`.dll`, `.exe`, `.so`, `.dylib`, compiled
Python, archives, encoded or obfuscated blobs) is allowed, because some publishers
ship proprietary libraries. It makes the pack **High risk**: the listing and the
install prompt name every such file with its size, hash, Authenticode signer when it
is signed, and the result of a malware check, and say plainly that it could not be
reviewed. Malware checks look up hashes only; files are never uploaded to a
third-party service, so proprietary binaries are not shared. A pack without a licence
file is shown as "No licence".

### 4.4 How pack code loads and runs

**One gate for all pack code.** Every path that loads a pack's code goes through one
loader: `Invoke-Maester`, `Invoke-MtTest`, `Connect-Maester`, `Disconnect-Maester`,
`Test-MtConnection` and `Get-MtTenantContext`. Before any pack file runs, the loader
checks the files against the digest in the lock file, the repository's numeric ID,
the organisation's policy and the blocklist (section 9.8). A pack that fails any check
does not load, wherever it was called from. Commands that only read metadata
(`Get-MtPack`, `Get-MtConnector`, `Find-MtPack`) read the manifest and the AST and run
nothing.

**One private module per pack.** 3.0 loads each custom test file into its own private
module (3.0 section 5.1); a pack's helpers, connector and tests are loaded together
into one private module, so its tests can call its helpers. Function names must
therefore be unique within a pack (validation reports `DuplicateFunctionName`). Files
are loaded by path, never through `[scriptblock]::Create`, so execution policy and
App Control apply to them (section 9.11). The module can call Maester's exported
commands and nothing private. Its tests go through the same engine as every other test:
static discovery, the same gates, the same parameter binding and config overrides.

**A pack can never pass as a built-in check.**

- `Source` on every pack row is `Custom`, whatever the pack's `suite.json` says (the
  closed list consumers already understand, as 3.0 appendix A.6 planned). The reserved
  `Package` field carries the pack `Id`, version and commit.
- A suite `Id` in a pack must start with the pack's code (`CNT`, `CNT.Admin`).
- **Reserved tags** cannot be set by a pack, on a test or in a `suite.json`: the
  built-in suite and source names (`Maester`, `MT`, `CIS`, `CISA`, `EIDSCA`, `ORCA`,
  `AD`, `AZDO`, `XSPM`) and their categories. So `-Tag CIS` never selects pack code.
  Functional tags such as `Preview` and `LongRunning` stay available.
- **The report shows packs apart.** Pack results appear in their own section, one group
  per pack with its publisher, badges and risk level, and each pack has its own pass
  rate. The headline score counts built-in and custom tests only, so a pack that always
  passes cannot inflate it.

### 4.5 Test IDs: `MP.<code>.<number>`

Built-in IDs are unique because the build checks them, and custom tests only have to be
unique in one tenant's folder. Pack tests are written by publishers who do not know
each other and installed side by side, so they get their own namespace:

- **Every pack test ID starts with `MP.`** ("Maester Pack"), then the publisher's
  code, then a number: `MP.CNT.0001`. A four-digit number is recommended; any segments
  the 3.0 ID grammar allows may follow the code. From an ID alone, anyone can tell that
  the test comes from a pack, and who published it.
- **`MP.` is a reserved prefix**, like `MT.` and `CIS.`. No built-in uses it, a custom
  test that uses it gets the reserved-prefix warning, and a pack test that does not use
  it fails validation. So a pack can never supply a built-in ID.
- **A code is two to five characters**, letters and digits, starting with a letter,
  compared case-insensitively and written in capitals: `CNT`, `NWT`, `FAB1`.

**A code belongs to a publisher: one GitHub user or organisation.** Each owner holds
exactly one code, and each code belongs to exactly one owner, permanently. All of an
owner's packs use it, which matches pack IDs (`contoso.google-workspace`) and keeps the
number of codes small.

- **Claiming: first index wins.** There is no reservation step. The pack's manifest
  declares `"Code": "CNT"`, and the first time the indexer sees any repository of an
  owner that holds no code yet (after an install or a "Request indexing"), it claims
  the code for that owner if the code is free and the version passes validation.
  "Request indexing" works on the default branch before any release, so a publisher
  can claim a code the day they pick it. The claim is recorded against GitHub's numeric
  owner ID, so it survives a rename of the user or organisation; an account deleted and
  re-created under the same name does not inherit it. The index publishes all claims
  in `codes.json`.
- **Several packs, one code.** An owner's packs share one number space, so their IDs
  must be unique across all of them. The indexer checks every new version against the
  owner's other listed packs. A publisher with several packs can keep them apart with a
  segment per pack (`MP.CNT.GWS.0001`, `MP.CNT.OKTA.0001`) or with number ranges.
  `New-MtTest` picks the next number that is free in the pack and in the owner's other
  listed packs.
- **Permanent.** An owner cannot switch codes on its own, because its IDs are keys in
  users' configs and result history. A maintainer can change one in a dispute, and the
  old code is then retired, never reassigned. A repository that moves to another owner
  keeps its IDs for the same reason; the index records it as an exception under the old
  code.
- **Checking a code is free** before using it: `Find-MtPack -Code CNT` and
  packs.maester.dev/codes/CNT show whether it is available, held (and by whom) or
  reserved. `Test-MtPack` checks the manifest against `codes.json` before you publish.
  Availability is not a reservation: the claim happens at first index.
- **Reserved codes** cannot be claimed (section 4.6): built-in suite names, names that
  look official, offensive words, and **known brands**, so nobody but Google can take
  `GOOG` and nobody but Okta can take `OKTA`.
- **Against squatting:** one code per owner, ever; a claim needs a version that passes
  validation, from an owner account older than 30 days; and a claim whose owner never
  reaches a listed release within 90 days is released.
- **IDs are never reused.** The index keeps a ledger, per owner, of every ID it has
  ever listed and the title it had. A version that brings back a removed ID for a
  different check is not listed (`IdReused`), so an ID in someone's config or history
  always means the same check.
- **The official code.** Packs from the maester365 organisation use `MAES`
  (`MP.MAES.0001`), reserved for it.
- **Before the index exists** (phase 1), publishers pick codes with no one to claim
  them from. `Test-MtPack` ships a snapshot of the reserved list so they avoid brands
  from the start. When the index opens, codes used by public packs that had a GitHub
  release before launch are claimed for their owners first, in order of that release's
  publish date, before new claims are accepted.

**What the code guards at each stage:**

- **Index:** a version is listed only if every test ID is `MP.<code>.*` with the code
  its owner holds, no ID is used by the owner's other packs, and no ID comes back with
  a new meaning. Otherwise it is not
  listed, and the publisher is told exactly why and how to fix it (section 7.7).
- **Install:** `Install-MtPack` refuses a pack whose IDs clash with an installed pack
  or a custom test in the project, naming both. An unlisted pack installs with the
  index's reason for not listing it, or with a warning that its code is not held by its
  owner.
- **Run:** the 3.0 rule still backs this up: two non-built-in tests with the same ID
  give `DuplicateId` error rows and neither runs, so nothing silently replaces another
  test.

### 4.6 Reserved codes and brands

The index keeps a reserved list, rebuilt weekly by a workflow in the index repository
and published in `codes.json` with the reason for each entry. It is made from
maintained public lists rather than one we curate by hand:

| Source | What it adds | Licence |
| --- | --- | --- |
| **Simple Icons** (`simple-icons/simple-icons`, the brand list behind most developer sites' logos) | 3,400+ technology and consumer brands: every brand name and alias that fits a code once reduced to letters and digits (`Okta`, `Zoom`, `Slack`, `Cisco`, `Meta`, `Box`, `AWS`, `GCP`) | CC0 (public domain) |
| **S&P 500 constituents** (`datasets/s-and-p-500-companies`) | The stock tickers of major companies, which are exactly the 2 to 5 letter codes a brand would choose (`MSFT`, `GOOG`, `AMZN`, `CRM`, `PANW`, `CRWD`) | ODC-PDDL (public domain) |
| **Our own short list** in the index repository | Built-in suite names (`MT`, `CIS`, `CISA`, `AD`, `AZDO`, `ORCA`, `EIDSCA`, `XSPM`), names that look official (`MS`, `MSFT`, `MAESTER`), `MAES` (assigned to maester365), product acronyms the lists miss (`M365`, `O365`, `GWS`, `AAD`), and offensive words | — |

A code is blocked when it equals an entry, or an entry followed by one digit (`OKTA1`),
after reducing both to capital letters and digits. Brand names may still appear in the
segments after a publisher's code: `MP.CNT.OKTA.0001` is contoso's Okta check, and
says so.

**When the company itself wants its code,** it contacts the project (the security
contact or an issue form in the index repository). A maintainer checks that the request
comes from that company: a GitHub organisation that GitHub has verified for the brand's
domain, or email from that domain. The assignment is a reviewed commit in the index
repository that maps the code to the organisation's numeric owner ID, and the pack is
then listed with that code like any other.

The same lists protect **connector service names** (section 6.3): a bare platform name
such as `Okta` or `GoogleWorkspace` is reserved for an official or brand-assigned
connector, and community connectors use their publisher's code as a namespace
(`CNT.GoogleWorkspace`).

A code someone already holds is not taken away when a new brand joins the lists,
because its IDs are already in users' configs. A brand can raise a dispute over a held
code that has no listed pack yet.

### 4.7 What packs can rely on

Packs call Maester's public commands, so those commands become a contract with every
publisher.

- **The pack API** is a published list: the exported commands and parameters packs may
  call (`Invoke-MtGraphRequest`, `Add-MtTestResultDetail`, `Get-MtConnectionState` and
  the rest), the `[MaesterTest]` attribute schema, the manifest schema and the connector
  contract. Anything not on the list is not part of it, and `Test-MtPack` warns when a
  pack uses it.
- **Changes follow semantic versioning.** Something on the list is deprecated in one
  minor release, with a warning when a pack uses it, and removed only in the next major.
- **The index re-checks listed packs** against each new Maester release, statically:
  a pack that calls a command or parameter the release removed is marked "Not
  compatible with Maester 4.0" on its page and in `Find-MtPack`, and its publisher is
  told through the status page (section 7.7).

## 5. Installing, updating and running

### 5.1 Commands

| Command | What it does |
| --- | --- |
| `Find-MtPack [-Query] [-Service] [-MaximumRisk] [-Code]` | Searches the Maester Packs index; `-Code` shows whether a code is available, held or reserved. |
| `Install-MtPack <source> [-Version] [-Scope Project\|User]` | Resolves, downloads, validates, shows the approval prompt, and records the pack in config and lock file. |
| `Restore-MtPack [-Source <folder>]` | Installs exactly what the lock file says, checking every digest; no prompts. Used by CI and maester-action. A pack GitHub no longer serves is skipped with a warning (section 5.5); `-Source` reads a `Save-MtPack` bundle instead of GitHub. |
| `Save-MtPack -Path <folder>` | Writes the locked packs, their Gallery modules, their listings and the current blocklist into a folder, for vendoring into a repository or carrying into an air-gapped network. |
| `Update-MtPack [<id>] [-Version]` | Moves to a newer tag; shows what changed and asks again if the pack now uses more. |
| `Uninstall-MtPack <id>` | Removes it from config and lock file. |
| `Get-MtPack [<id>]` | Installed packs with version, risk level, badges, whether an update or a block applies. |
| `New-MtPack` / `Test-MtPack -Path` | For publishers: scaffold a pack repository, and run the indexer's validation and scans locally. `Test-MtPack -Remote owner/repo` shows the index's result for a release, including why it is not listed (section 7.7). |
| `Get-MtConnector [<service>]` | Built-in services and installed connectors, with their settings and help. |

`<source>` is `owner/repo`, `owner/repo/<folder>`, a GitHub URL, `owner/repo@v1.2.0`
or `@<commit>`, or a local folder for development (never recorded as installable from
anywhere else). Downloads use `GH_TOKEN` or `GITHUB_TOKEN` when set, sent to GitHub's
own hosts only: private repositories need it, and it avoids GitHub's limit of 60
anonymous API requests an hour, which a company network behind one address reaches
quickly. Nothing is sent to the index for a download that needed a token.

### 5.2 Where things go

- **`maester-config.json`** gets a `Packs` section: what the user asked for, plus
  per-pack settings. It sits with the rest of the run configuration, in the same 3.0
  config layers.

  ```json
  "Packs": [
    { "Source": "contoso/maester-google-workspace", "Version": "^1.2", "Enabled": true }
  ]
  ```

- **`maester-packs.lock.json`** sits next to it and pins each pack, and every pack it
  requires, to a commit; records the test IDs each pack provides; the numeric repository and owner IDs and the publisher at
  approval; the content digest; the risk level and scan result at install time and the
  risk level the user accepted; the approved `Uses` block; and the hashes of the whole
  Gallery module closure. Committing it is how a team reviews what runs in CI.
- **The digest** is SHA-256 over the sorted list of paths and file hashes. A
  PowerShell file's Authenticode signature block is left out of its hash, so an
  organisation can sign reviewed packs (section 9.11) without breaking the lock file.
- **The store** is a cache keyed by digest under `~/.maester/packs/`. Files are
  written read-only, and the digest is checked again every time the pack loads, so a
  modified file stops the pack from running instead of running modified code.
- **Which lock file applies**, in order: `-PackLock <path>`; `MAESTER_PACK_LOCK`; the
  lock file next to the `maester-config.json` that 3.0's config discovery resolved; and
  only when there is no project config at all, the user scope
  (`~/.maester/maester-config.json` and its lock file), as `npx skills add -g` installs
  globally. A host that passes `-Config` as an object passes `-PackLock` too.
  `Connect-Maester` and every other command find installed connectors the same way.

### 5.3 The install prompt

```text
PS> Install-MtPack contoso/maester-google-workspace

  Google Workspace security baseline  contoso.google-workspace 1.2.0
  Source      github.com/contoso/maester-google-workspace @ 3f9c2e1 (tag v1.2.0)
  Publisher   contoso   ★ Microsoft MVP   ✔ GitHub-verified organisation
  Risk        LOW: text files only; every scan passed
              packs.maester.dev/p/contoso/maester-google-workspace/security
  Adds        42 tests (MP.CNT.*) and the "Google Workspace" connector
  Reaches     Google Workspace: admin.googleapis.com, oauth2.googleapis.com
  Microsoft   none declared

  This pack runs PowerShell code inside your Maester session, with access to every
  connection in it. Install it? [Y] Yes  [N] No  [F] List files  [?] Help (default is "N"):
```

A **High** risk pack shows why and asks for more than a keypress:

```text
  Risk        HIGH: contains compiled code that could not be scanned
              lib/Contoso.Gws.Client.dll  412 KB  signed by Contoso Ltd  no malware match
  Only install this if you trust the publisher. Type the pack ID to confirm:
```

Everything in the prompt that comes from the pack (name, description, file names, the
signer, connector output) has control and bidirectional-text characters removed and
is capped in length, and the lines Maester writes itself (Risk, Reaches, Microsoft and
the question) come last. So text in a pack cannot redraw the Risk line or hide what
follows. The same cleaning applies to `Find-MtPack`, `Get-MtPack` and connector
output in `Connect-Maester`.

Without a console (scripts, CI), `-AcceptRisk Medium` or `-AcceptRisk High` is
required for those levels. The lock file records the accepted level, and
`Restore-MtPack` fails if a version's level is higher than the one recorded.

A pack that is **not listed** (new, private, or not yet indexed) gets the same prompt
with "Not listed: not scanned by Maester Packs" and the findings of the local scan
that `Test-MtPack` runs, which assigns the same risk levels. It needs
`-AllowUnlisted` unless the organisation's policy forbids unlisted packs outright
(section 9.7). This is how the first installer of a new pack, usually its author, gets
it indexed.

### 5.4 Updates

`Update-MtPack` never runs on its own and `Invoke-Maester` never updates a pack. It
shows the version change, the number of changed files, and any change to `Uses`, to
connectors or to the risk level. If the pack now reaches more than was approved (a new
service, scope, host or module), its risk level rose, or the repository moved to
another owner, the user approves again, as browsers do for extensions that ask for new
permissions. It also lists the test IDs the update adds and removes, and calls out
removed IDs that the user's config refers to (in `TestSettings` or `Selection`) and
added ones that a `DefaultAction` of `Skip` or `OnUnknownId` will treat differently. `Get-MtPack` and the start of an
`Invoke-Maester` run mention available updates in one line.

**Release cooldown.** `Update-MtPack` and `Install-MtPack` without a version pick the
newest release that is at least 72 hours old and has passed its scans; a newer one is
shown but needs `-Version` or `-IncludeRecent`. Most malicious releases from a hijacked
account are found within that window (ChainDrop, section 3.1). The window is a policy
setting. Its clock is the time the index first saw the release, or in phase 1 the
`published_at` time GitHub records for the release. Commit and tag dates are not used,
because anyone can forge them. A lightweight tag with no GitHub release has no
trustworthy date, so the prompt says the cooldown could not be applied.

### 5.5 Running

`Invoke-Maester` loads the packs in the resolved config, checks each digest against
the lock file and the blocklist (section 9.8), and adds their tests to the plan.
Selection works as for built-ins (`-Tag`, `-TestId`, config `Selection`), and
`Packs[].Enabled = false` turns a pack off without uninstalling it. `-DryRun` lists
pack tests like any other. A pack that fails to load gives one `Error` row per test
with reason `PackLoadFailed` rather than stopping the run.

**A pack that is no longer on GitHub is skipped, and the run continues.** If the
repository was deleted or made private, or the release was removed, and the
digest-verified copy is not already in the local store, Maester does not fail. It skips that
pack, its tests (whose IDs the lock file records) appear as `NotRun` rows with reason
`PackUnavailable`, and the report shows a warning naming the pack, the version and what
GitHub returned. A copy that fails its digest check is never run either; it is skipped
the same way, with a warning that the files changed. Maester Packs keeps no copies of
publishers' repositories. Teams that need restores to work whatever happens to a
repository commit a `Save-MtPack` bundle and restore from it with `-Source`.

**A run with packs only** (Google Workspace, say, and no Microsoft 365 connection) uses
`-SkipBuiltIn`, so the report is not filled with skipped built-in checks. With no Graph
connection there is no tenant ID, so 3.0's tenant-specific config layer is skipped,
and the report header shows the connected services from `TenantContext` instead of a
Microsoft 365 tenant.

### 5.6 maester-action and CI

maester-action restores from the committed lock file:

```yaml
- uses: maester365/maester-action@v2
  with:
    restore_packs: true            # runs Restore-MtPack against the lock file in the repo
  env:
    MAESTER_CNT_GOOGLEWORKSPACE_CREDENTIAL: ${{ secrets.GWS_SERVICE_ACCOUNT_JSON }}
```

Nothing is resolved in CI: the lock file decides what runs. A pack GitHub no longer
serves, or whose files fail the digest check, is skipped with a warning in the report
and the run continues (section 5.5); a blocked pack gives `NotRun` rows with the
advisory (section 9.8).

### 5.7 Which commits can be installed

GitHub serves any commit in a repository's fork network under the original
repository's name, so `contoso/x@<commit>`, or a lock file edited in a pull request,
could otherwise install an attacker's fork while showing contoso's name and badges.
At install, restore and index time, the commit must be reachable from a tag or branch
of the named repository itself, checked through GitHub's API. A tag that later points
at a different commit than when it was first seen is recorded and shown as a warning
on the pack's page and in `Get-MtPack`.

### 5.8 Lifecycle

| State | Set by | What happens |
| --- | --- | --- |
| **Listed** | The index | Shown, ranked, installable |
| **Deprecated** | The publisher: `"Deprecated": { "Message": "...", "Replacement": "owner/repo" }` in the manifest of a new version | Shown with the message and the replacement; installs and updates warn |
| **Yanked version** | The publisher: `"Yanked": [{ "Version": "1.1.0", "Reason": "..." }]` in a later version's manifest | Not offered for install or update; lock files that pin it still restore, with a warning. For mistakes, not malice |
| **Archived** | GitHub: the repository is archived | Labelled "Archived: no longer maintained"; still installable |
| **Gone** | GitHub: the repository was deleted or made private, or the release removed | Shown as "No longer available"; runs skip it with a warning (section 5.5) |
| **Delisted** | The publisher (`"Listed": false`, or a request) or the index (failing, or a legal takedown, section 9.10) | Hidden and not installable from the index; copies already installed keep running |
| **Blocked** | Maintainers, for malice (section 9.8) | Never loads anywhere |

## 6. Connectors: hooking into Connect-Maester

### 6.1 The contract

A connector is four functions in the pack, plus an optional fifth, `Renew` (section 6.5), all named in the manifest. They are ordinary
PowerShell functions with comment-based help; Maester reads their parameters
statically, so `Get-MtConnector` can show the settings without running anything.

```powershell
function Connect-GwsService {
    <#
    .SYNOPSIS
    Signs in to Google Workspace for Maester.
    #>
    [CmdletBinding(DefaultParameterSetName = 'OAuth')]
    param(
        # The super administrator to sign in as, or to impersonate through
        # domain-wide delegation when a service account is used.
        [Parameter(Mandatory)] [string] $AdminEmail,

        # The service account key JSON, for unattended runs. Secret.
        [Parameter(Mandatory, ParameterSetName = 'ServiceAccount')] [securestring] $Credential,

        # The OAuth client JSON, for a browser sign-in. Secret.
        [Parameter(ParameterSetName = 'OAuth')] [securestring] $OAuthClient
    )
    $token = ...                                   # the pack's own sign-in code
    Set-MtConnectionState -Value @{ Token = $token; AdminEmail = $AdminEmail }
}

function Test-GwsService { [OutputType([bool])] param() [bool](Get-MtConnectionState) }

function Disconnect-GwsService { Clear-MtConnectionState }

function Get-GwsServiceContext {
    # Non-secret facts for Get-MtTenantContext and the report.
    $state = Get-MtConnectionState
    @{ Customer = $state.CustomerId; PrimaryDomain = $state.Domain; Edition = $state.Edition }
}
```

- **`Connect`** signs in and stores what the tests need with `Set-MtConnectionState`.
  It can be interactive (browser, device code) or not, depending on its parameters.
- **`Test`** returns `$true` when connected. It must be fast; the service gate calls
  it once per run.
- **`Disconnect`** is optional.
- **`Describe`** is optional and returns non-secret facts. They go into the result's
  `TenantContext.Services.<Service>` and show on the report's connection summary.
- **The connector's manifest entry** also lists what it needs on its own platform and
  which environment variables it reads, for example:

  ```json
  "Permissions": {
    "Role": "Super Admin",
    "Scopes": ["admin.directory.user.readonly", "admin.reports.audit.readonly",
               "cloud-identity.policies.readonly"]
  },
  "Environment": ["GOOGLE_APPLICATION_CREDENTIALS"]
  ```

  These two settings feed the install prompt and the Connector tab. The scans compare
  them with the scopes and variables the code actually uses. Once packs can be isolated,
  they also become the environment allowlist of the pack's container. A connector can fall back to its platform's
  standard variables, the way Steampipe plugins do.
- **`Set-`, `Get-` and `Clear-MtConnectionState`** are new public commands. The state
  is held per service and per pack: a pack's code gets only the state of its own
  connectors and of the services it declares from a connector pack it requires
  (section 4.2).
  In-process this is a guard against mistakes, not a security boundary; isolation
  (section 9.4) makes it one later.

### 6.2 What Connect-Maester does

```powershell
Connect-Maester -Service Graph, GoogleWorkspace
Connect-Maester -Service CNT.GoogleWorkspace -ServiceSetting @{
    'CNT.GoogleWorkspace' = @{ AdminEmail = 'admin@contoso.com'; Credential = $key }
}
```

1. `-Service` is no longer a fixed `ValidateSet`. It accepts built-in names and the
   services of installed connectors, with tab completion for both and a clear error
   for an unknown name. A platform name (`GoogleWorkspace`) resolves to the one
   installed connector for that platform; if two installed connectors serve it, the
   full service name is required and the error lists both. `-Service All` keeps its
   3.0 meaning and does not include connectors; they are always named, like
   `ActiveDirectory` and `GitHub` today.
2. Settings for each connector are gathered in this order, last wins: the config
   file's `Connections.<Service>` section (non-secret values only),
   environment variables `MAESTER_<SERVICE>_<SETTING>` (dots become underscores:
   `MAESTER_CNT_GOOGLEWORKSPACE_CREDENTIAL`), then `-ServiceSetting`. Because the
   service name carries the publisher's code, one publisher's connector can never
   receive the environment secrets meant for another's.
   A secret setting (`[securestring]`, `[pscredential]`, or a name ending in
   `Secret`, `Key`, `Token` or `Credential`) is refused from the config file. Values can
   reference a SecretManagement vault: `"Credential": "vault:GwsKey"`.
3. Connect-Maester calls the connector's `Connect` inside the pack, and adds a row to the summary table it already prints:
   `Google Workspace  Connected  contoso.com (C01abc)`, or `Failed` with the error
   summary, or `Not installed` when no installed pack provides the service.
4. `Disconnect-Maester` calls each connector's `Disconnect`. `Test-MtConnection
   -Service CNT.GoogleWorkspace` and `Get-MtTenantContext` call `Test` and `Describe`.

### 6.3 What the engine does with it

The 3.0 service registry (`assets/MaesterServiceRegistry.psd1`) becomes layered: the
built-in entries, then one entry per installed connector with `Probe` pointing at the
connector's `Test` function. Everything 3.0 already does with a service then works for
pack services unchanged: `[MaesterTest(Service = 'CNT.GoogleWorkspace')]` validates, the
gate gives `Skipped`/`ServiceNotConnected` (or `NotRun`/`OptInServiceNotConnected`
when the connector says `OptIn`), and `ServiceNotRegistered` covers a test whose pack
is missing.

- **Service names.** A community connector's service is `<code>.<Name>`
  (`CNT.GoogleWorkspace`), so it is unique because the code is, and nobody can squat a
  platform: whoever wrote the first Okta connector does not become the connector every
  Okta pack must use and does not receive every user's `MAESTER_OKTA_*` secrets. A bare
  platform name (`GoogleWorkspace`, `Okta`) is reserved for an official connector from
  maester365 or one assigned to the brand itself (section 4.6). Each connector also
  declares its `Platform`, which drives the site's platform filter and the
  `Connect-Maester` shortcut above. Names are 3 to 40 letters and digits, starting with
  a letter, plus the one dot after the code. `All`, `None`, `EOP`, `Pack`, `Packs`,
  `Telemetry`, `Maester` and every built-in service name and alias are reserved, so no
  service's environment variables can collide with Maester's own (`MAESTER_PACK_POLICY`,
  `MAESTER_TELEMETRY_OPTOUT`). A pack uses another pack's service by requiring it.
- **Parameter kinds** (3.0 section 3.4): a pack can add kinds under its service name
  (`CNT.GoogleWorkspace.OrgUnit`) for test parameters, so a UI can offer a picker.
- **Licences and editions:** `CompatibleLicense` stays Microsoft-specific. A connector
  reports its platform's edition in `Describe`; until a generic edition gate exists, a
  test that needs a higher edition skips itself with `Add-MtTestResultDetail
  -SkippedBecause Custom`.

### 6.4 Built-in services as connectors (later)

The built-in services can move onto the same contract one at a time (GitHub and Active
Directory first, since they are self-contained), so `Connect-Maester` becomes a
dispatcher over connectors and the contract is proven by Maester's own code. This is
not needed for phase 1 and is not planned for the Microsoft 365 services, whose module
load order is delicate.

### 6.5 Long runs, token lifetime, and one code path

**In v1 every pack runs in-process**, so a pack's tests use the same Microsoft
connections as the built-in tests and behave the same over a long run: a module
connected interactively, with a certificate, a client secret or a managed identity
renews its own tokens; a session connected with `-AccessToken` stops working when that
token expires, as it does for built-in tests today. Nothing about packs changes this.

**Connectors renew their own platform tokens.** The optional fifth function,
`Renew`, is called by the engine before a test when the connection state's `ExpiresOn`
is less than ten minutes away, and a pack's helpers can call it on a 401. A Google
service account mints a new token at any time; an OAuth sign-in uses its refresh
token. A connector without `Renew` is reconnected with the settings it was first given
when its `Test` returns `$false`, if they allow a non-interactive sign-in.

**Pack code is the same in every execution model.** The rules below make that true,
and `Test-MtPack` warns when code breaks them:

- Reach Microsoft services only through Maester's commands (`Invoke-MtGraphRequest`,
  `Invoke-MtAzureRequest`, and the Exchange, Teams and SharePoint cmdlets of the
  session Maester connected). Never call `Connect-*`, read tokens, or keep a client of
  your own.
- Reach your own platform only through your connector's state
  (`Get-MtConnectionState`) and `Renew`.
- Keep no state in global or script variables between tests.

When packs can be isolated later (section 9.4), the same files run in a container: the
host connects the declared Microsoft services there, the connector signs in there, and
the engine renews tokens between tests. Tests run one at a time, so a token is never
swapped in the middle of one. A pack that must stay in the main session for a very
long run sets `Packs[].Isolation = "InProcess"` in config, if the policy allows it.

### 6.6 Microsoft permissions a pack needs

A pack that tests Microsoft 365 more deeply may need Graph scopes Maester does not ask
for. Without them its tests would get a 403 and turn into `Error` rows; added
carelessly, they would erode the read-only identity that section 9.4 relies on, because
consent given to the shared Microsoft Graph PowerShell app stays on that app for every
later script.

- **`Uses.GraphScopes`** lists them, and the install prompt shows them.
- **Nothing is requested silently.** `Connect-Maester -IncludePackScopes` adds the
  scopes of installed packs, listing each pack and scope before signing in, and
  `Get-MtGraphScope -IncludePackScopes` returns the same list. For unattended runs with
  an app registration, `Install-MtPack` prints the permissions to grant, and
  `Update-MtMaesterApp` can add them to the Maester app, the recommended identity, so
  consent never lands on the shared Graph PowerShell app.
- **A missing scope is a skip, not an error.** Before a pack's tests run, the engine
  compares its declared scopes with the current token. A test whose pack needs a scope
  the token lacks is `Skipped` with reason `MissingScope`, naming the scope.
- **Writes are declared and expensive.** `Uses.TenantWrites` lists every change a pack
  can make to a tenant (`Graph: PATCH /policies/...`, `ExchangeOnline: Set-*`). Any
  write scope or declared tenant write makes the pack **High** risk, and the scans fail
  a pack whose code writes without declaring it.
- Exchange Online, Teams, SharePoint and Azure have no per-scope consent: a pack that
  lists those services gets the session with whatever roles the signed-in identity has,
  and the prompt says so.

## 7. Discovery, the index and hosting

### 7.1 Architecture

```text
 Install-MtPack ──install event──▶ Worker  packs.maester.dev/api/v1/events
                                     │  dedupe, rate limit ─▶ D1 (daily installs, queue)
                                     ▲  queue read with a read-only key
                                     │
       GitHub Actions in maester365/packs-index (public repository: free minutes)
         scan job (untrusted, no secrets): fetch ▶ check ▶ validate ▶ scan ▶ listing
         publish job (protected environment): sign ▶ build site ▶ deploy
                                     │  wrangler deploy
                                     ▼
 Browser, Find-MtPack ◀── packs.maester.dev
                           static assets: pages, index.json, codes.json, blocklist.json
                           Worker: /api/v1/stats, /api/v1/search, /api/v1/events
```

Everything that can be a static file is one, because Cloudflare serves static assets
free and without limit. The Worker does only three things: accept install events,
serve install counts, and (once the index is too big for one file) search. It holds
no token that can write to GitHub.

### 7.2 From install to listing

1. **Install.** `Install-MtPack owner/repo` downloads the archive anonymously. If the
   GitHub API says the repository is public, the client posts an event to
   `/api/v1/events`: source (`github.com/owner/repo`), folder, commit, pack `Id`,
   Maester version, a random installation ID, and whether it ran in CI. It is fire and
   forget with a two-second timeout. `Restore-MtPack` sends a lighter event, at most
   one per restore, that counts as "active in CI", not as an install.
2. **Worker.** Checks the event's shape, applies a per-client rate limit, and writes
   at most one row per pack, installation and day, and one per pack, hashed IP and day
   (section 7.6). If the repository or commit is new, it adds it to a queue table.
   Triggering a workflow directly (`repository_dispatch`) would need a GitHub token
   with write access to the index repository inside the Worker, so it does not; the
   index workflow reads the queue instead.
3. **Scan job (untrusted).** A workflow in the public `maester365/packs-index`
   repository runs every ten minutes and reads the queue through the Worker with a
   read-only key. Its scan job has **no secrets and a read-only `GITHUB_TOKEN`**,
   because it handles hostile input: archives, manifests, README files and the text of
   "Request indexing" issues. Untrusted values reach scripts only through environment
   variables, are checked against strict patterns (a repository name is
   `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$`), and are never pasted into a workflow expression
   such as `${{ github.event.issue.title }}`, the classic injection route. For each
   queued repository and commit, **ignoring everything the client claimed except the
   repository name**, it:
   - looks the repository up through the GitHub API (numeric IDs, public, owner
     account age, tags, organisation verification) and checks that the commit is
     reachable from a tag or branch of that repository (section 5.7);
   - downloads the archive for the commit itself, refusing archives over the size or
     file-count limits, with paths that escape the folder, links, or a suspicious
     compression ratio, and computes the digest;
   - runs validation and every scan (section 9.6) with a time limit per scan, and
     assigns the risk level. Results are cached by digest **and scanner version**, so
     the same content is not scanned twice by the same scanners, and every listed
     version is scanned again when the scanners or malware signatures change;
   - writes the listing as a build artifact: manifest, README, test catalog (read
     statically, as 3.0's catalog is), connector settings, `Uses`, scan results,
     binaries, risk level, badges, digest.

   A version that fails is recorded with its reasons and not listed; the publisher
   sees why (section 7.7).
4. **New versions.** The scheduled run also asks GitHub, in one GraphQL query per
   batch, for new release tags on listed repositories, so a new version is scanned
   before anyone installs it.
5. **Publish job (privileged).** A separate job, in a protected GitHub environment
   that only the default branch can use, takes the scan job's artifact. It is the only
   job with secrets: the index signing key, the Cloudflare token, and a GitHub
   App allowed to push to one data branch. It:
   - commits listings to the `listings` branch. Repository rulesets let only that App
     write there and let nobody, the App included, push to `main`, where people's
     decisions (blocklist, disputes, official list) arrive by reviewed pull request;
   - signs `index.json` with the online index key (section 9.8), builds the static
     site and deploys it with `wrangler`: pages, `index.json`, per-pack JSON,
     `codes.json` (who holds each code and service name) and the current
     `blocklist.json`, which is signed separately and offline.
6. **Show.** Pages fetch install counts from `/api/v1/stats` (edge-cached for five
   minutes). `Find-MtPack` reads `index.json` and searches it locally.

All third-party actions in the index workflows are pinned to full commit SHAs.

### 7.3 Ranking

- **All time:** deduplicated installs.
- **Trending:** installs in the last 24 hours against the pack's daily average over
  the previous seven days, counting only packs with installs from at least ten
  distinct hashed IPs that day.
- **New:** first listed in the last 14 days, newest first.

Blocked packs are not ranked. High risk packs are ranked and carry their badge on the
row; the leaderboard has a risk filter.

### 7.4 Curation by pull request

The index repository holds what people decide, as reviewable commits: blocklist
entries and advisories, the official list, featured packs, and disputes over codes
and service names (section 4.5). A "Request indexing" link opens an issue there that the
indexer picks up, for publishers who want a listing before anyone installs. Issue text
is only ever data to the indexer (section 7.2).

### 7.5 Keeping the cost near zero

| Piece | Runs on | Free tier | When it would cost |
| --- | --- | --- | --- |
| Pages, `index.json`, `blocklist.json`, per-pack JSON | Cloudflare static assets | Free and unlimited requests | Never |
| Install events, counts, search | Cloudflare Worker | 100,000 requests a day, 10 ms CPU each | Workers Paid, US$5 a month: 10 million requests a month, then US$0.30 per million |
| Install counts, queue | Cloudflare D1 | 5 million rows read and 100,000 written a day, 5 GB | Included in Workers Paid up to 50 million writes a month |
| Indexing, scanning, site build, deploy | GitHub Actions in a public repository | Standard GitHub-hosted runners are free for public repositories | Never, on standard runners |
| Malware checks for binaries | ClamAV in the workflow; optional VirusTotal hash lookups | VirusTotal's public API: 500 lookups a day, non-commercial use | A paid malware service, if ever needed |
| AI-assisted review (optional) | GitHub Models from the workflow | Free rate-limited tier | A paid model API, if quality needs it |
| Domain | packs.maester.dev on the existing Cloudflare zone | — | Nothing new |

What keeps it there:

- Static first: the Worker never renders a page.
- One D1 write per deduplicated install; repeated events are ignored inserts, which
  write nothing.
- The CLI sends one event per install and a lighter one per CI restore, never one per
  test run.
- Search runs in the client over `index.json` until that file is too large.
- Counts are edge-cached for five minutes, so most page views never reach D1.
- A digest is scanned once per scanner version; only new commits and scanner updates
  cost workflow time, and that time is free.
- On the free plan, going over a limit fails the request rather than billing; the CLI
  ignores a failed event. Move to Workers Paid when the daily request limit is reached
  regularly, and set a usage notification there.

Expected cost: nothing at launch; US$5 a month once installs and page views pass
roughly 100,000 API requests a day.

### 7.6 Spam and gaming

The client is open source, so nothing can prove that an event came from a real
install. The design assumes counts can be inflated and keeps them out of every trust
decision; the measures below make inflation expensive and visible.

- **Fake installs.** Each pack counts at most one install per installation ID and one
  per hashed IP per day, so one machine minting new IDs counts once. The Worker hashes
  the IP with a salt that rotates daily and never stores the IP itself. A per-client
  rate limit (the Workers rate-limiting binding) caps events per minute. Trending needs
  installs from ten distinct hashed IPs that day. A scheduled job looks for bursts from
  few networks (Cloudflare gives the client's network, ASN, on every request) or sudden
  spikes on a new pack, freezes the pack's rank and opens an issue.
- **Junk listings.** A listing needs a valid manifest, its owner's code, a tagged
  release, at least one test or a connector, and an owner account older than 30 days. An owner gets at most
  one new pack listed a day. A pack whose digest matches another pack is marked a
  duplicate and hidden. Names and IDs close to existing ones are flagged, and
  `maester`/`maester365` are reserved.
- **Fake reports.** Reports go through GitHub issues, which need a GitHub account. A
  pack is hidden automatically only after reports from several distinct accounts older
  than 30 days, and a maintainer then decides.
- **The site and API.** Static pages are behind Cloudflare's CDN. Any browser form
  the site adds uses Turnstile, which is free. A WAF rate-limiting rule covers
  `/api/*`. **Bot Fight Mode should stay off for the zone**: on the free plan it
  applies to the whole zone and cannot be skipped per path, so it would challenge
  PowerShell's requests to the API and to `index.json`, and maester.dev's visitors too.
- **No search telemetry.** skills.sh's CLI sends search queries; `Find-MtPack`
  does not.

### 7.7 Why a pack is not listed

A publisher must never have to guess. Every version the index looks at gets a status,
and every reason it is not listed comes with the exact files or IDs and the fix. The
same text appears in five places:

- **packs.maester.dev/status/{owner}/{repo}**: every version seen, listed or not;
- **`Test-MtPack -Remote owner/repo`** in the terminal;
- **`Test-MtPack -Path .`**, which runs the same checks locally against `codes.json`
  before anything is published, so most problems show up before tagging;
- **the `maester365/pack-scan` action** in the publisher's repository, which fails
  with the same messages;
- **the install prompt** of an unlisted pack.

By default the index does not open issues on publishers' repositories, so it never
becomes noise in someone else's tracker. (Anyone can open an issue on a public
repository with issues turned on, but a GitHub App can only do so where it is
installed, so this would need a bot account.) A publisher who wants issues can opt in
with `"Notify": "Issues"` in the manifest; the index then opens one issue per version
that is not listed, blocked or disputed.

| Reason | What the publisher sees (examples) | Fix |
| --- | --- | --- |
| `CodeMismatch` | Test IDs must start with `MP.CNT.`, the code contoso holds. 3 tests use `MP.CTO.`: `MP.CTO.0001`, `MP.CTO.0002`, `MP.CTO.0003`. | Rename the IDs, or correct `Code` in the manifest |
| `CodeTaken` | The code `IDP` is held by fabrikam. contoso has no code yet. | Pick a free code (`Find-MtPack -Code`) |
| `CodeReserved` | `OKTA` is reserved for the brand Okta (Simple Icons). If you represent Okta, contact us to have it assigned. | Pick another code, or ask for the brand's code (section 4.6) |
| `CodeMissing` | `maester-pack.json` has no `Code`. | Add one |
| `DuplicateTestId` | `MP.CNT.0001` is already used by contoso/maester-okta. | Renumber, or add a segment per pack (`MP.CNT.GWS.0001`) |
| `ServiceReserved` | `GoogleWorkspace` is reserved for an official or brand-assigned connector. | Name yours `CNT.GoogleWorkspace`, or require the official connector pack |
| `IdReused` | `MP.CNT.0012` was "Gmail forwarding is off" in 1.0.0 and is now "Drive sharing is limited". | Give the new check a new number |
| `CommitNotInRepository` | Commit `9f1e2d3` is not reachable from any tag or branch of contoso/maester-okta (it may come from a fork). | Tag the release in the repository itself |
| `NotCompatible` | Calls `Get-MtExoMailboxAudit`, which Maester 4.0 removed. | Update the pack; listed as compatible up to 3.x until then |
| `InvalidPack` | `tests/Test.MP.CNT.0004.ps1:12`: a statement outside a function runs when the file loads. | Fix the file and line named |
| `UndeclaredReach` | `connectors/GoogleWorkspace.ps1:40` calls `api.example.com`, which `Uses.Network` does not declare. | Declare it, or remove the call |
| `DuplicateContent` | Same content as fabrikam/okta-pack (digest `sha256:91c4…`). | Publish your own work |
| `OwnerTooNew` | The contoso account is 12 days old; it can be listed from 25 Oct 2026. | Nothing: indexed again automatically |
| `DailyLimit` | contoso already listed a new pack today. | Nothing: listed tomorrow |
| `NoRelease` | Indexed from the default branch: code `CNT` is now held by contoso. Tag a release to be listed. | Tag a release |
| `Blocked` | Blocked: advisory MPA-2026-0003. | See the advisory; appeal in the index repository |

A repository the index cannot see (private, or not found) has no status page, and
`Test-MtPack -Remote` says so. Every status page also has a JSON form, and the index
publishes feeds of new advisories and of status changes per publisher
(`/feeds/advisories.json`, `/feeds/p/{owner}.json`), so publishers and organisations
can watch without polling pages.

## 8. The site: packs.maester.dev

The mockup canvas that accompanies this document shows the leaderboard, the pack page
(Low, High and Blocked states), the publishing guide and the terminal flow.

### 8.1 How it is built

A static site generated by the index workflow with **Astro** and deployed as a
Cloudflare Worker with static assets on the `packs.maester.dev` custom domain. Astro
builds static output by default, adds small client scripts only where needed, and can
import maester.dev's colour and type tokens so the two sites look like one. Docusaurus,
already in the repository, was the alternative; it is shaped for documentation and
rebuilds every page on every change. maester.dev's navigation gets a
"Packs" link; the two sites deploy independently.

### 8.2 Pages

| URL | Page | Shows |
| --- | --- | --- |
| `/` | **Leaderboard** | Search; All time / Trending / New tabs; filters by platform (the services connectors provide, plus Microsoft 365 add-ons), risk level and badge; rows with rank, icon, pack, `owner/repo`, badges, risk, platform, tests, an 8-week sparkline and installs; a "How listing works" panel and a publish link |
| `/p/{owner}/{repo}`, or `/p/{owner}/{repo}/pack/{folder}` for one pack in a multi-pack repository | **Pack** | Header with badges, risk level, publisher, description and platforms; install box with PowerShell, maester-action and lock file tabs; tabs: **Overview** (the README, sanitised), **Tests** (ID, title, severity, service, each linking to its page), **Connector** (what it connects to, how to sign in, the settings table with secret markers and environment variable names, what it needs on the platform), **Security** (risk level and why, every compiled file with hash and signer, each scan's result, declared `Uses` against what was found, repository signals, repository ID, advisories), **Versions** (tag, commit, date, digest, risk level, changes to `Uses`, yanked versions); a sidebar with installs, version, first seen, last release, licence, required Maester version, GitHub stars and "Report this pack" |
| `/p/{owner}/{repo}/tests/{id}` | **Test** | The test's Markdown (description, remediation) and its attribute data |
| `/p/{owner}` | **Publisher** | Badges, the code and service names the publisher holds, packs, security contact |
| `/codes/{code}` | **Code lookup** | Whether a code is available, held (and by whom) or reserved, and why |
| `/status/{owner}/{repo}` | **Indexing status** | Each version the index has seen: listed, or not listed with every reason and its fix (section 7.7) |
| `/official`, `/platform/{service}`, `/category/{slug}` | **Lists** | Filtered leaderboards |
| `/advisories[/{id}]` | **Advisories** | Blocked packs and versions, what happened, what to do |
| `/publish` | **Publishing guide** | The steps of section 10.3, the rules of section 4.3, risk levels and badges |
| `/security` | **Security model** | Section 9 in plain words, for admins and their security reviewers |
| `/b/{owner}/{repo}.svg` | **Badge** | Risk level and installs, for a pack's README |
| `/feeds/...` | **Feeds** | JSON feeds of advisories and of status changes per publisher (section 7.7) |
| `/terms`, `/privacy` | **Policies** | Terms of listing and use, and the privacy notice (section 9.10) |
| `/api/v1/...` | **API** | `events` (POST), `stats`, `search` |

Publishers and their packs live under `/p/`, so a GitHub account named `official`,
`status` or `security` can never collide with a site page; `pack` and `tests` are
reserved path segments under a repository.

A blocked pack's page keeps its URL, shows the advisory at the top and removes the
install command. A delisted pack's page says so and removes the install command;
deprecated and archived packs show their notice above the install box.

**Content from packs is untrusted on the site too.** READMEs and test Markdown are
sanitised; outbound links carry `rel="ugc nofollow noopener"`; remote images are
removed (they would track visitors); `icon.svg` is converted to a PNG by the scan job,
never served as SVG; names and descriptions have control and bidirectional-text
characters removed and are capped in length. A pack name or description that claims to
be "official" or to come from Microsoft, Maester or a reserved brand is flagged and
not listed unless the claim is true (an official pack, or a brand-assigned code).

### 8.3 In the product

`Find-MtPack` shows the same columns as the leaderboard, `Get-MtPack` links to each
pack's page, and the install prompt links to its Security tab, so the website, the
terminal and CI show the same information.

## 9. Security

### 9.1 Why packs need more than skills.sh does

An agent skill is mostly instructions; an agent runs its scripts with a person in the
loop. A pack is code that Maester runs automatically, often unattended in CI, with the
connections of a security administrator: Graph read access to the whole directory,
and often Exchange Online, Azure, Teams and SharePoint sessions that carry the
signed-in identity's admin roles, plus CI secrets in the environment. On a privileged
session a malicious pack could change the tenant as well as read it (add a mail
forwarding rule, add a credential to an application). The design assumes that some
packs will be malicious and that some publisher accounts will be compromised, and
limits what one bad pack can do.

### 9.2 Threats

| Threat | Example | Main defences |
| --- | --- | --- |
| Malicious publisher | A "baseline" pack that posts the directory to its own server | Undeclared network use fails validation; risk levels; a plain-words prompt about running in-process; blocklist; organisation policy; isolation later |
| Compromised publisher account | A stolen token pushes a new tag with a payload, as in the 2025 npm worms | Commit pinning and digests; no automatic updates; new approval when a pack reaches more; every version scanned; blocklist by version |
| A hijacked release that looks legitimate | The owner's account pushes a tag and the pack's own workflow builds it (ChainDrop) | The 72-hour release cooldown (section 5.4), with scans inside that window; blocklist |
| Bait and switch | Harmless until popular, then a malicious update | As above, plus the update shows what changed in `Uses` and in risk level |
| Hidden code | A compiled library or an encoded blob that scanners cannot read (Trail of Bits got past three skill scanners this way) | Such content always makes the pack High risk, named file by file, with explicit consent to install |
| Impersonation and typosquatting | `maester365-cis`, `micros0ft.entra` | Reserved names; pack ID must start with the GitHub owner; similarity flags; badges come from GitHub and the MVP directory, not from the pack |
| Faking a built-in result | A pack defines `MT.1001` and always returns `$true`, so the report shows a built-in control as passed | Pack test IDs must start with `MP.`; a built-in ID can never come from a pack (section 4.5) |
| Repository takeover | Owner renames or deletes the repo; someone re-creates the old name | The index and lock file record GitHub's numeric repository and owner IDs; a changed ID freezes the listing and fails restores; policy matches IDs, not names |
| A fork's commit under the original's name | `contoso/x@<commit>` where the commit lives only in an attacker's fork | The commit must be reachable from a tag or branch of the named repository (section 5.7) |
| Passing as a built-in check | A pack sets `Source: CIS` or the tag `CIS`, so `-Tag CIS` runs it and the report scores it with the built-ins | `Source` forced to `Custom`, reserved tags and suite names, pack results and pass rates shown apart (section 4.4) |
| Owning a platform's connector | The first `Okta` connector would receive every user's `MAESTER_OKTA_*` secrets | Community connectors are namespaced by code; bare platform names are reserved (section 6.3) |
| Text that redraws the prompt | A description with terminal control or bidi characters hides the Risk line | Pack text is cleaned and capped, and Maester's own lines print last (section 5.3); SVG icons are converted to PNG (section 8.2) |
| Permission creep | A pack needs `Directory.ReadWrite.All`, and consent persists on the shared Graph app | Scopes listed and requested only with `-IncludePackScopes`; write scopes make a pack High risk; consent goes to the Maester app (section 6.6) |
| Code that escapes the gate | Connector code runs from `Connect-Maester`, which an install-time check never sees | One loader gate for every path that loads pack code (section 4.4) |
| Fake installs | Inflating installs to push a pack up the leaderboard | Section 7.6; popularity never changes a risk level or a badge |
| Code that runs on load | `using module`, class definitions, top-level statements | Function-only files are a validation rule (section 4.3); no install scripts exist |
| Dependency attack | A typosquatted or compromised PowerShell Gallery module | Exact version pins; package hash in the lock file; modules shown in the prompt and scanned |
| Local tampering | Malware edits a pack in the store | Read-only files; digest checked on every load |
| Report as a channel | A result embeds a remote image whose URL carries data | The report already sanitises Markdown (DOMPurify); pack rows also lose remote images and show link targets |
| Secrets in results | A pack writes a token into a result | Results are scanned for token patterns before writing, as for built-ins |
| Index compromise | A forged listing, a removed blocklist entry, or an old blocklist replayed by a proxy | Untrusted scanning separated from signing and deploying (section 7.2); listings and blocklist signed with separate keys under an offline root, with serial numbers and expiry (section 9.8) |
| Attacking the indexer | A hostile archive, or an issue title that injects into a workflow script | No secrets in the scan job; archive limits; untrusted text only through environment variables (section 7.2) |

### 9.3 Principles

1. **No code runs at install or discovery.** Install downloads, validates and records;
   discovery reads the AST.
2. **Pinned and verified on every load.** Commit, digest and repository ID.
3. **Nothing changes without approval**, and more access needs new approval.
4. **A pack declares what it reaches**, and the scans hold it to that.
5. **Say what we could not check.** Unscannable content is named and makes the pack
   High risk; it is never silently passed.
6. **Trust is visible and revocable**: risk levels, badges, the blocklist.
7. **Organisations decide** what may be installed.
8. **Honest about limits.** Code in the Maester process can do anything the session
   can. The prompt and the docs say so in plain words.

### 9.4 Where pack code runs

**v1: in-process, for every pack**, exactly like custom tests: one private module per
pack in Maester's runspace, with access to every connection in the session, the
environment and the user's files. This keeps v1 simple and makes long runs behave like
today (section 6.5). The defences in v1 are therefore the ones that act before code
runs (validation, scans, risk levels, consent, cooldown, policy) and the blocklist that
acts at every run.

**The strongest control in v1 is the identity.** The docs recommend running Maester as
a dedicated identity with read-only roles (read-only Graph permissions, Global Reader,
read-only Exchange and Azure roles). Maester's default Graph scopes are already
read-only; the guidance extends that to every service. Then even a malicious pack can
only read.

**Later: isolation.** Microsoft's own guidance is that a child process running as the
same user is not a security boundary; a container, a separate OS user or a virtual
machine is. So isolation, when it comes, is a container per pack, using the 3.0
partition contract (3.0 section 13.1): the host runs each untrusted pack as its own
partition, with only the Microsoft services it declared connected as short-lived
access tokens, its connector signing in inside the container, environment secrets
left out, network egress limited to `Uses`, and rows merged with
`Merge-MtMaesterResult -SameRun`. A hosted service that runs Maester, or maester-action
on Linux runners, can offer this first; a local machine can when Windows and macOS give
PowerShell a native sandbox. A same-user "pack host" process was considered and
deferred: it removes in-memory tokens and environment secrets from reach, but it can
still read the user's files, including on-disk token caches.

### 9.5 Badges

Badges say **who** published a pack; the risk level says **what** is in it. Neither is
a code review.

| Badge | Means | Source |
| --- | --- | --- |
| **Official** | Published in the maester365 organisation and reviewed like built-in checks | The repository owner |
| **Microsoft MVP** | The GitHub account that owns the repository is listed on a current, public Microsoft MVP profile | A weekly sync from the public MVP profile directory (the unauthenticated endpoints behind mvp.microsoft.com), matching the GitHub link MVPs add to their profile |
| **GitHub-verified organisation** | The owning organisation has verified its domain with GitHub | GitHub's organisation API (`is_verified`) |

The MVP badge is best-effort, as decided: the directory API is undocumented, and the
link is self-declared by the MVP. A badge never changes a risk level. A publisher verification
programme (signed releases, reviews, a Verified badge) is out of scope for v1 and
listed for phase 3.

### 9.6 Risk levels and scanning

| Level | What it means | Install | Shown as |
| --- | --- | --- | --- |
| **Low** | Text files only (PowerShell, Markdown, JSON); every scan passed | The normal prompt | Green "Low risk" |
| **Medium** | Text only, with findings worth reading: dynamic code (`Invoke-Expression`, `[scriptblock]::Create`, inline `Add-Type`), URLs built at run time, process start, PowerShell Gallery modules that are themselves script only | The prompt lists the findings; `-AcceptRisk Medium` without a console | Amber "Medium risk" |
| **High** | Compiled code (in the pack or in any Gallery module it needs), archives, or content that cannot be scanned (encoded or obfuscated); any Graph write scope or declared tenant write (section 6.6); or a scan could not complete | Named file by file; typed confirmation; `-AcceptRisk High` without a console | Red "High risk: install only if you trust the publisher" |
| **Blocked** | A malware match, or confirmed malicious by a maintainer | Never loads; install refused | Advisory |

Code that reaches something it did not declare is not a risk level: it fails
validation and is not listed (section 4.3).

**What the index workflow runs**, all in GitHub Actions on the public index repository:

1. **Validation:** the section 4.3 rules, the manifest schema, the 3.0 test schema.
2. **Static analysis:** PSScriptAnalyzer plus pack rules for dynamic code, network
   calls and their hosts, token and secret access, process start, writes outside temp,
   calls into Maester's private scope, and **tenant writes** (Graph `POST`/`PATCH`/
   `DELETE`, Exchange and Az `Set-`/`New-`/`Remove-` commands). A check pack should not
   write; one that does shows "Writes to your tenant".
3. **Secret scanning** for committed keys and tokens (gitleaks).
4. **Binary inventory:** every file whose content is not text, by its bytes rather
   than its extension, with size, SHA-256, Authenticode signer (checked on a Windows
   runner, also free for public repositories), a ClamAV scan, and an optional
   VirusTotal hash lookup within its public API terms. Nothing is uploaded.
5. **Dependencies:** each Gallery module exists at the pinned version, is not flagged,
   and is not a near-copy of a better-known name.
6. **Repository hygiene:** OpenSSF Scorecard, shown on the page.
7. **AI-assisted review (optional):** a model reads the code, and the diff from the
   previous version, against the pack's stated purpose. It can raise a finding for a
   maintainer; it never clears one.

The same scanners ship in `Test-MtPack`, so a publisher sees the result before
tagging, and an unlisted install gets a local risk level.

**Repository signals.** Many publishers already run Codacy, SonarCloud, Snyk,
CodeRabbit or PSScriptAnalyzer in their own repository. The index reads the check runs
GitHub records on the release commit and shows them on the Security tab under
"Repository signals", with the GitHub App that produced each one, so a "Codacy" result
really came from Codacy's app. They do not set the risk level: the publisher
configures those tools and can turn rules off; CodeRabbit reviews pull requests rather
than releases; and a check run says pass or fail, not what was checked. Our own scans
are free to run in Actions, so the risk level always comes from them. A reusable
`maester365/pack-scan` action lets a publisher run exactly our scanners in their own
repository.

### 9.7 Organisation policy

```json
"PackPolicy": {
  "MaximumRisk": "Medium",
  "AllowedPublishers": ["maester365", "contoso"],
  "RequireBadge": [],
  "AllowUnlisted": false,
  "TrustedSources": ["github.com/contoso-internal/maester-checks"],
  "RequireFreshBlocklist": false,
  "Index": "https://packs.maester.dev/index.json"
}
```

The policy is read from the run config, from `MAESTER_PACK_POLICY`, or from a
machine-wide file that device management can deploy, and the strictest value wins. It
applies at install, restore and run.

- `AllowedPublishers` names are resolved to GitHub's numeric owner IDs when the policy
  is first applied and the IDs are what is checked, so someone who re-registers a
  deleted name is not trusted by the old entry.
- `RequireBadge` can demand `Official` or `MicrosoftMvp`.
- `TrustedSources` lets an organisation's own packs, usually private repositories,
  install with `AllowUnlisted: false`; entries are repositories (resolved to their
  numeric IDs) or digests.
- `RequireFreshBlocklist` makes a run fail instead of continuing when no current
  blocklist can be fetched (section 9.8).
- `Index` can point at an internal mirror. The index and the blocklist are static
  files, so an organisation, or an air-gapped network, can host a copy; `Save-MtPack`
  bundles cover the packs themselves.

### 9.8 Revocation

- The index publishes a **signed blocklist** (`blocklist.json`) of pack, owner or
  repository IDs, version ranges or digests, a severity and an advisory link.
- **Freshness.** The signed payload carries a `Serial` that only goes up, an
  `IssuedAt` and an `Expires` (seven days ahead; the list is re-signed daily even when
  unchanged). The client rejects a list with a lower serial than one it has seen, so a
  mirror or a TLS-inspecting proxy cannot replay an old list, and treats an expired
  list as missing.
- **Keys.** An offline root key signs two working keys: an **index key**, used by the
  publish job to sign `index.json`, and a **blocklist key**, kept offline and used only
  to sign blocklist changes that maintainers have merged after review. Signatures name
  their key ID, the module ships the root's public key and the current working keys,
  and a new working key is introduced alongside the old one before the old one is
  retired, so clients on older versions keep verifying. If a working key is
  compromised, the root signs its revocation and a replacement. All keys are ECDSA
  P-256, which .NET verifies with no extra library.
- **Checks.** The loader gate (section 4.4) checks the blocklist before any pack code
  runs: in `Invoke-Maester`, `Invoke-MtTest`, `Connect-Maester` and the rest. The list
  is fetched with a short timeout and cached for an hour. A blocked pack does not load:
  its tests give `NotRun` rows with reason `PackBlocked`, a warning names the advisory,
  and `Get-MtPack` shows it.
- **When the index cannot be reached**, the default is to continue with the newest
  cached list and a warning (fail open), because a security tool that stops working
  when one website is down would be switched off. Ephemeral CI runners have no cache,
  so they fetch the list on every run; when that fails they continue with a warning.
  `PackPolicy.RequireFreshBlocklist` turns both into errors, and a list older than
  seven days always warns.
- **Phase 1 is covered from the start.** The checker, the keys and an empty signed
  blocklist ship with the first release that can install packs, so every pack
  installed before the marketplace exists can still be stopped later (section 12).
- **A block stops a pack from running; it never deletes it.** VS Code's kill switch
  once uninstalled a legitimate extension by mistake for two weeks; here removing the
  entry undoes a false positive at the next run. An entry can also be `Warn` (runs,
  with the advisory shown) for something suspicious but unproven.
- Reports come in through a "Report this pack" link on every page (a GitHub issue), the
  pack's `SecurityContact` and the project's security contact. Maintainers can block
  within hours, notify the publisher, and publish an advisory. A publisher can appeal
  in the index repository.

### 9.9 Privacy of the install event

The install event carries the pack source, commit, pack ID, Maester version, a random
installation ID and whether it ran in CI. The Worker hashes the IP with a daily salt
for deduplication and stores neither the IP nor any tenant, user or machine
identifier. Nothing is sent for a source that needed credentials to download (a
private repository). `MAESTER_TELEMETRY_OPTOUT=1`, `DO_NOT_TRACK=1` or config
`Telemetry.Disabled` turns it off.

### 9.10 Terms, licences and takedowns

Before the public launch the site needs policies, written with legal advice:

- **Terms of listing** for publishers, which apply when a pack is listed: the
  publisher has the right to publish what is in the repository; it grants Maester Packs
  a licence to display its listing, README and test documentation; no malware, no deception, no collecting data the pack
  does not need; and the project may delist or block a pack. A publisher that does not
  agree uses `"Listed": false` (section 4.2) or asks to be delisted; installing directly
  from the repository still works.
- **Repositories with no licence** are listed with metadata, the test catalog and a
  short README excerpt only, since nothing grants more.
- **Trademark and copyright complaints** have their own process and form, separate from
  security takedowns: a complaint delists the pack (installed copies keep running) while
  it is resolved, and a counter-notice can restore it. Only security problems use the
  blocklist.
- **A disclaimer for users:** packs are third-party code; the Maester project does not
  review every pack and gives no warranty; risk levels and badges are signals, not
  guarantees.
- **A privacy notice** for the site and the install event (section 9.9).

### 9.11 Locked-down Windows (AllSigned and App Control)

On machines whose execution policy is AllSigned, or that use App Control for Business
(WDAC), PowerShell runs only signed scripts in full language mode.

- Pack files are loaded by path (section 4.4), never through `[scriptblock]::Create`,
  so those controls apply to them, and Maester can never be used to get around them.
- An unsigned pack does not load on such a machine, and `Install-MtPack` says so when
  it sees the policy. An organisation that has reviewed a pack can sign its files with
  its own code-signing certificate; the digest leaves signature blocks out
  (section 5.2), so signing does not break the lock file.

## 10. User journeys

### 10.1 An admin adds Google Workspace checks

```powershell
Find-MtPack google
#  Pack                                  Badges      Risk     Tests  Installs
#  contoso/maester-google-workspace      MVP         Low         42     3.1k
#  fabrikam/gws-extra                                Medium       9      210

Install-MtPack contoso/maester-google-workspace      # prompt as in section 5.3
Get-MtConnector GoogleWorkspace                      # settings and how to get a key
Connect-Maester -Service Graph, GoogleWorkspace      # browser sign-in for both
Invoke-Maester                                       # built-ins and MP.CNT.* in one report
```

### 10.2 The same in CI

The admin commits `maester-config.json` and `maester-packs.lock.json`, adds the
service account key as a repository secret, and sets `restore_packs: true` on
maester-action (section 5.6). A later `Update-MtPack` shows up as a lock file diff in a
pull request, with the changes in `Uses` and risk level listed by the command for the
PR description.

### 10.3 A publisher creates and lists a pack

1. `New-MtPack -Id contoso.google-workspace -Code CNT -Service CNT.GoogleWorkspace` scaffolds the
   repository: manifest, suite, a sample test, a connector skeleton, README, and the
   `pack-scan` workflow.
2. They write tests with the same `New-MtTest`, `Invoke-MtTest` and `Get-MtTest` they
   would use for custom tests, and run `Test-MtPack` until it is clean.
3. They check the code is free (`Find-MtPack -Code CNT`) and click "Request indexing"
   to claim it straight away, or let the first install claim it (section 4.5).
4. They push and tag `v1.0.0`, ideally with GitHub's immutable releases turned on.
5. Installing it once (`Install-MtPack contoso/... -AllowUnlisted`) sends the install
   event; the index validates and scans the tag, and the pack is listed, usually within
   the hour. No form and no approval queue. "Request indexing" does the same without an
   install.

### 10.4 A malicious version is found

A report comes in for `fabrikam/gws-extra` 1.4.0. A maintainer adds it to the
blocklist. At their next run every machine that has it skips its tests with
`PackBlocked` and shows the advisory; `Restore-MtPack` fails in CI so the pipeline
goes red; the pack's page shows the advisory and the install command is removed.
1.3.0 stays installable unless the advisory covers it.

## 11. Changes to Maester

| Area | Change | Phase |
| --- | --- | --- |
| Pack loader | Read `maester-pack.json`; one loader gate for every path that loads pack code (digest, repository ID, policy, blocklist); one private module per pack loaded by path; `DuplicateFunctionName`; `Source` forced to `Custom`, reserved tags and suite names; fill `Package` on rows | 1 |
| Install | `Install-`, `Restore-`, `Update-`, `Uninstall-`, `Get-`, `Save-MtPack`; GitHub archive download without git, with `GH_TOKEN` support; commit reachability check; digest without signature blocks; lock file with the dependency closure and numeric IDs; store; risk acceptance; ID diff on update; cooldown on GitHub's release time | 1 |
| Revocation | The blocklist checker with serial and expiry, the root and working public keys, and an empty signed blocklist served from packs.maester.dev | 1 |
| Config | `Packs`, `Connections` and `PackPolicy` sections in the 3.0 config schema and resolver; `-PackLock` and `MAESTER_PACK_LOCK` | 1 |
| Validation | `Test-MtPack` (section 4.3 rules, the `MP.<code>` ID rule, the reserved-list snapshot, the pack API check, local scans and risk level); `New-MtPack` scaffold; a template repository | 1 |
| Test schema | `MP.` added to the reserved prefixes, so custom tests written before packs ship get the warning; this one line can land in 3.0 | 1 (or 3.0) |
| Connectors | Layered service registry with namespaced service names; `Set-`/`Get-`/`Clear-MtConnectionState`; `Exports` for connector packs; `Get-MtConnector`; `Connect-Maester -Service` opened up with `-ServiceSetting` and platform shortcuts; `Disconnect-Maester`, `Test-MtConnection`, `Get-MtTenantContext` dispatch to connectors; `Renew` before tests | 1 |
| Permissions | `-IncludePackScopes` on `Connect-Maester` and `Get-MtGraphScope`; pack scopes in `Update-MtMaesterApp`; the `MissingScope` skip reason | 1 |
| Output safety | Cleaning of pack text in prompts and command output | 1 |
| Report | A Packs section grouped by pack with publisher, badges, risk and its own pass rate; headline score without pack rows; remote images stripped for pack rows | 1 |
| maester-action | `restore_packs` input; pack environment variables passed through | 1 |
| Pack API | The published list of commands, schemas and contracts packs may rely on, and the deprecation policy | 1 |
| Index client | `Find-MtPack`; signed index verification; install event | 2 |
| Isolation | Container partitions per pack for hosts that can run containers | 3 |
| Built-in connectors | GitHub and Active Directory on the connector contract | later |

Outside the module (phase 2): the `maester365/packs-index` repository with its split
scan and publish workflows, rulesets and scanners; the `maester365/pack-scan` reusable
action; the Worker and D1 database; the static site; the MVP
directory and brand-list syncs; the signing keys and their custody; and the terms of
listing.

## 12. Phases

1. **Phase 1, packs without the marketplace (3.1).** The format, GitHub install with
   the lock file, connectors and `Connect-Maester` dispatch, the loader gate, the
   permissions work, `New-` and `Test-MtPack`, the template, maester-action restore,
   and the published pack API. Packs run in-process. Every install is "unlisted" and
   gets the local scan and risk level. **The blocklist checker, the keys and an empty
   signed blocklist ship in this phase**, so packs installed now can still be stopped
   once the marketplace exists. The first official pack is Google Workspace (code
   `MAES`, service `GoogleWorkspace`), against the CISA SCuBA Google Workspace
   baselines that ScubaGoggles implements. It proves the connector contract with both a
   browser sign-in and a service account; the licence of any code reused needs
   checking.
2. **Phase 2, Maester Packs.** The Worker and D1, the index workflows and scanners,
   risk levels and badges, the signed index, `Find-MtPack`,
   packs.maester.dev, the terms of listing and the privacy notice, and the claim window
   for codes used during phase 1 (section 4.5). The public launch waits for the
   blocklist, the cooldown, the risk levels, the indexer's split jobs and the terms,
   because listing community code without them would ask users to trust it blindly.
3. **Phase 3, isolation and verification.** Container isolation per pack; a publisher
   verification programme with signed provenance and a Verified badge.
4. **Later.** Other Git hosts (Azure DevOps Repos, GitLab), private registries for
   organisations, built-in services on the connector contract.

## 13. Alternatives considered

- **maesterpacks.com** instead of packs.maester.dev: section 2.1.
- **Publish packs to the PowerShell Gallery as modules.** Familiar, versioned, with
  Microsoft's scanning. Not chosen as the primary route: it needs a publish step and an
  API key (no "push to GitHub and it appears"), a module runs code when it is imported,
  and the Gallery has had typosquatting problems. Gallery modules stay available as
  declared dependencies.
- **A curated registry where every pack is submitted by pull request.** Safer at the
  start, but slow for publishers and a review burden for maintainers, and not the
  model chosen. The index repository still takes pull requests for takedowns, the
  official list and disputes.
- **A full server for the index** (as skills.sh runs). Not needed: static files plus
  a Worker with D1 cover events, counts and search at almost no cost, and the client
  contract does not change if this grows.
- **Refuse compiled code.** Simplest to scan, but it would exclude publishers with
  proprietary libraries. Compiled code is allowed and always High risk instead.
- **Rely on the publisher's own scanners** (Codacy, CodeRabbit and others). Shown as
  repository signals, not used for the risk level: section 9.6.
- **A same-user pack host process.** Deferred in favour of in-process for v1 and
  containers later: section 9.4.
- **Constrained Language Mode for packs.** Maester defines classes and cannot run under
  CLM (3.0 section 17), and CLM is enforced per session, not per module, so it cannot
  isolate a pack inside Maester's runspace.

## 14. Decisions

### Ruled by the owner (2026-10-07)

- Names: **pack** and **Maester Packs**.
- Domain: **packs.maester.dev** (section 2.1 agrees).
- Hosting: **Cloudflare** for the site and a small Worker API; **GitHub Actions** for
  indexing and scanning.
- **Compiled code is allowed**, called out and made High risk.
- **v1 runs packs in-process**; isolation comes later.
- **No verification programme in v1**; badges for Official, Microsoft MVP and
  GitHub-verified organisations instead.
- A pack is **listed on its first install** that passes validation and the scans, from
  an owner account older than 30 days; an owner gets **one new pack listed a day**.
- The site is built with **Astro**.
- **High risk packs are shown on the leaderboard by default**, with their risk badge;
  the risk filter can hide them.
- The **MVP badge** uses the undocumented MVP directory API as best-effort.
- The **first official pack is Google Workspace**.
- **Pack test IDs are `MP.<code>.<number>`**, with a two- to five-character code per
  publisher (GitHub user or organisation), claimed at the first index of any of its
  repositories, first come, first served; no reservation pull request. A pack that is
  not listed shows the publisher why (sections 4.5 and 7.7).
- **Known brands cannot be claimed as codes** by default, using Simple Icons, S&P 500
  tickers and a short list of our own; the company itself can ask for its code
  (section 4.6).
- **The design review of 2026-10-07 is applied in full**: commits must belong to the
  named repository (5.7); one loader gate and no passing as built-ins (4.4);
  namespaced connector service names (6.3); permissions packs need (6.6); the blocklist
  in phase 1, with freshness and key hierarchy (9.8, 12); the split indexer (7.2);
  packs that disappear from GitHub are skipped with a warning, with no copies kept by
  Maester Packs (5.5); lifecycle states (5.8); numeric IDs and the ID ledger (4.2, 4.5); the
  pack API (4.7); locked-down Windows (9.11); and terms and takedowns (9.10).
- maester365's own code is **`MAES`**.

### Still open

- **Setup you would own:** the GitHub App the publish job uses to write the
  `listings` branch; the offline root and blocklist signing keys and the publish job's
  index key; the rulesets and protected environment on `maester365/packs-index`; the
  Cloudflare account, zone settings and Worker secrets; and the terms of
  listing and privacy notice, with legal advice.

## 15. Not yet verified

- **Cloudflare details:** that Bot Fight Mode cannot be scoped per path on the free
  plan; whether the Workers rate-limiting binding is included on the free plan; and the
  number of free WAF rate-limiting rules. Pricing in section 7.5 is from Cloudflare's
  Workers pricing page on 2026-10-07.
- **The MVP directory API** is undocumented and may change or rate-limit.
- **The brand lists:** the exact Simple Icons data file and alias fields to read, and
  how many legitimate short codes the lists block (expected to be a small share of the
  2 to 5 character space, but the 3-letter codes most affected).
- **GitHub Models' free tier** and VirusTotal's public API terms for a non-commercial
  open-source index need confirming before either is relied on.
- **Static rules for load-time execution:** that function-only files plus the listed
  bans cover every way a PowerShell file can run code when dot-sourced.
- **Scanner quality:** false-positive rates of the pack rules on real community code
  (the built-in checks are the first corpus).
- **Container isolation** (phase 3): access-token sign-in for each Microsoft module
  inside a container, and renewal between tests.
- **The commit reachability check:** which GitHub API call proves cheaply that a
  commit is reachable from a tag or branch of the named repository (the compare API is
  the likely one), and its cost against the anonymous rate limit.
- **Signing key custody:** where the offline root and blocklist keys live and who
  holds them, and how the publish job's index key is protected.
- **The `MissingScope` gate:** reading granted scopes and roles reliably from delegated
  and app-only tokens across clouds.
- **The skills.sh mechanics** are taken from its public CLI source (commit `958f4b7`)
  and site on 2026-10-07 and may change; its server code is not public, so the
  deduplication and trending formulas are as documented, not as read. The facts about
  Steampipe, Terraform, VS Code, npm and ScubaGoggles are from their documentation on
  the same date.

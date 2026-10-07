# Design: Maester Packs (third-party test packs and connectors)

> **Status: DRAFT for owner review. Nothing is implemented.** Drafted 2026-10-07 on
> top of the Maester 3.0 design ([maester-3.0-design.md](maester-3.0-design.md),
> section 12.2 fixed the package seams that 3.0 ships). Owner rulings of 2026-10-07
> are applied: the names (*pack*, *Maester Packs*), the domain (packs.maester.dev),
> hosting on Cloudflare with GitHub Actions doing the indexing and scanning, compiled
> code allowed behind a High risk level, packs running in-process in v1, no publisher
> verification programme in v1, and the recommendations of section 14. Section 14
> lists what is still open; section 15 lists what is not yet verified.

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
  install. Every version is pinned and digest-checked on every load. Updates are
  explicit, a new release waits out a 72-hour cooldown, and a pack that reaches more
  needs new approval. Every version is scanned and given a **risk level**: Low (text
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
  "RequiresMaester": "3.1",
  "Code": "CNT",
  "Suites": ["tests"],
  "Helpers": ["helpers"],
  "Connectors": [
    {
      "Service": "GoogleWorkspace",
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
    "Services": ["GoogleWorkspace"],
    "GraphScopes": [],
    "Network": ["admin.googleapis.com", "oauth2.googleapis.com", "www.googleapis.com"],
    "Modules": []
  },
  "Categories": ["Google Workspace", "Identity", "Email"]
}
```

- **`Id`** is `<publisher>.<name>`, lower case. `Publisher` must match the GitHub owner
  for a listed pack (section 9.2). `maester` and `maester365` are reserved for official
  packs.
- **`Code`** is the publisher's code, two to five letters or digits, held by the GitHub
  user or organisation that owns the repository. Every test ID in the pack is
  `MP.<Code>.<number>`, for example `MP.CNT.0001` (section 4.5).
- **`Uses`** declares what the pack reaches: the services its tests list, extra
  Microsoft Graph scopes, network hosts outside the declared services, and PowerShell
  Gallery modules. It drives the install prompt, the scans (anything the code reaches
  that is not declared fails validation) and, once packs can be isolated, what a
  pack's container gets (section 9.4).
- **`Uses.Modules`** pins PowerShell Gallery modules by exact version, for example a
  Google API client. They are installed with `Install-PSResource -RequiredVersion`,
  which runs nothing at install. Their package hash goes into the lock file and is
  checked on restore, because PowerShell does not check a module's signature when it
  loads it.
- **`Requires`** names other packs this one needs, by `Id` and minimum version, most
  often a **connector pack**:

  ```json
  "Requires": { "Packs": [ { "Id": "contoso.google-workspace-connector", "MinVersion": "1.0" } ] }
  ```

  A pack can ship its own connector, as above, or depend on one, as Powerpipe mods
  depend on Steampipe plugins. The split is recommended when several test packs target
  one platform: one connector, one sign-in, one service name, reviewed once.
  `Install-MtPack` installs required packs with their own prompts.
- Unknown keys are ignored with a warning, as for `suite.json`. `RequiresMaester`
  works as in 3.0: an older Maester gives each test a `RequiresNewerMaester` row.

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
- No symbolic links; at most 50 MB per pack and 20 MB per file.

**Compiled and unscannable content** (`.dll`, `.exe`, `.so`, `.dylib`, compiled
Python, archives, encoded or obfuscated blobs) is allowed, because some publishers
ship proprietary libraries. It makes the pack **High risk**: the listing and the
install prompt name every such file with its size, hash, Authenticode signer when it
is signed, and the result of a malware check, and say plainly that it could not be
reviewed. Malware checks look up hashes only; files are never uploaded to a
third-party service, so proprietary binaries are not shared. A pack without a licence
file is shown as "No licence".

### 4.4 How pack tests run

A pack is loaded the way 3.0 loads a custom folder (3.0 section 5.1): one private
module per pack containing its helpers, connector and test functions. It can call
Maester's exported commands and nothing private. Its tests go through the same
engine: static discovery, the same gates, the same parameter binding and config
overrides, the same result rows.

On each row: `Source` is `Custom` (the closed list consumers already understand, as
3.0 appendix A.6 planned), `Suite` is the suite's `Id`, and the reserved `Package`
field is filled with the pack `Id`, version and commit. The report groups and filters
by `Package`; nothing else in the report changes.

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
  compared case-insensitively and written in capitals: `CNT`, `OKTA`, `AWS1`.

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
- **Reserved codes** cannot be claimed: built-in suite names (`MT`, `CIS`, `CISA`,
  `AD`, `AZDO`, `ORCA`, `EIDSCA`, `XSPM`), names that look official (`MS`, `MSFT`,
  `MAESTER`), and offensive words. Vendors' product names are not reserved; a vendor
  that wants its own name can raise a dispute while the code has no listed pack.
- **Against squatting:** one code per owner, ever; a claim needs a version that passes
  validation, from an owner account older than 30 days; and a claim whose owner never
  reaches a listed release within 90 days is released.
- **Connector service names** are claimed by the owner the same way, at the same first
  index: each service a pack's connectors provide must be free or already held by that
  owner.

**What the code guards at each stage:**

- **Index:** a version is listed only if every test ID is `MP.<code>.*` with the code
  its owner holds and no ID is used by the owner's other packs. Otherwise it is not
  listed, and the publisher is told exactly why and how to fix it (section 7.7).
- **Install:** `Install-MtPack` refuses a pack whose IDs clash with an installed pack
  or a custom test in the project, naming both. An unlisted pack installs with the
  index's reason for not listing it, or with a warning that its code is not held by its
  owner.
- **Run:** the 3.0 rule still backs this up: two non-built-in tests with the same ID
  give `DuplicateId` error rows and neither runs, so nothing silently replaces another
  test.

## 5. Installing, updating and running

### 5.1 Commands

| Command | What it does |
| --- | --- |
| `Find-MtPack [-Query] [-Service] [-MaximumRisk] [-Code]` | Searches the Maester Packs index; `-Code` shows whether a code is available, held or reserved. |
| `Install-MtPack <source> [-Version] [-Scope Project\|User]` | Resolves, downloads, validates, shows the approval prompt, and records the pack in config and lock file. |
| `Restore-MtPack` | Installs exactly what the lock file says, checking every digest; no prompts. Used by CI and maester-action. |
| `Update-MtPack [<id>] [-Version]` | Moves to a newer tag; shows what changed and asks again if the pack now uses more. |
| `Uninstall-MtPack <id>` | Removes it from config and lock file. |
| `Get-MtPack [<id>]` | Installed packs with version, risk level, badges, whether an update or a block applies. |
| `New-MtPack` / `Test-MtPack -Path` | For publishers: scaffold a pack repository, and run the indexer's validation and scans locally. `Test-MtPack -Remote owner/repo` shows the index's result for a release, including why it is not listed (section 7.7). |
| `Get-MtConnector [<service>]` | Built-in services and installed connectors, with their settings and help. |

`<source>` is `owner/repo`, `owner/repo/<folder>`, a GitHub URL, `owner/repo@v1.2.0`
or `@<commit>`, or a local folder for development (never recorded as installable from
anywhere else).

### 5.2 Where things go

- **`maester-config.json`** gets a `Packs` section: what the user asked for, plus
  per-pack settings. It sits with the rest of the run configuration, in the same 3.0
  config layers.

  ```json
  "Packs": [
    { "Source": "contoso/maester-google-workspace", "Version": "^1.2", "Enabled": true }
  ]
  ```

- **`maester-packs.lock.json`** sits next to it and pins each pack to a commit, its
  content digest (SHA-256 over the sorted file list and file hashes), its risk level and scan
  result at install time, the risk level the user accepted, the approved `Uses` block, and the hashes of any Gallery
  modules. Committing it is how a team reviews what runs in CI.
- **The store** is a cache keyed by digest under `~/.maester/packs/`. Files are
  written read-only, and the digest is checked again every time the pack loads, so a
  modified file stops the pack from running instead of running modified code.
- Without a project folder the user scope is used (`~/.maester/maester-config.json`
  and its lock file), as `npx skills add -g` installs globally.

### 5.3 The install prompt

```text
PS> Install-MtPack contoso/maester-google-workspace

  Google Workspace security baseline  contoso.google-workspace 1.2.0
  Source      github.com/contoso/maester-google-workspace @ 3f9c2e1 (tag v1.2.0)
  Publisher   contoso   ★ Microsoft MVP   ✔ GitHub-verified organisation
  Risk        LOW: text files only; every scan passed
              packs.maester.dev/contoso/maester-google-workspace/security
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
service, scope, host or module) or its risk level rose, the user approves again, as browsers do for
extensions that ask for new permissions. `Get-MtPack` and the start of an
`Invoke-Maester` run mention available updates in one line.

**Release cooldown.** `Update-MtPack` and `Install-MtPack` without a version pick the
newest release that is at least 72 hours old and has passed its scans; a newer one is
shown but needs `-Version` or `-IncludeRecent`. Most malicious releases from a hijacked
account are found within that window (ChainDrop, section 3.1). The window is a policy
setting.

### 5.5 Running

`Invoke-Maester` loads the packs in the resolved config, checks each digest against
the lock file and the blocklist (section 9.8), and adds their tests to the plan.
Selection works as for built-ins (`-Tag`, `-TestId`, config `Selection`), and
`Packs[].Enabled = false` turns a pack off without uninstalling it. `-DryRun` lists
pack tests like any other. A pack that fails to load gives one `Error` row per test
with reason `PackLoadFailed` rather than stopping the run.

### 5.6 maester-action and CI

maester-action restores from the committed lock file:

```yaml
- uses: maester365/maester-action@v2
  with:
    restore_packs: true            # runs Restore-MtPack against the lock file in the repo
  env:
    MAESTER_GOOGLEWORKSPACE_CREDENTIAL: ${{ secrets.GWS_SERVICE_ACCOUNT_JSON }}
```

Nothing is resolved in CI: a lock file entry that is missing, changed or blocked fails
the step with a clear message.

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
  is held per service and per pack: a pack's code gets only its own connector's state.
  In-process this is a guard against mistakes, not a security boundary; isolation
  (section 9.4) makes it one later.

### 6.2 What Connect-Maester does

```powershell
Connect-Maester -Service Graph, GoogleWorkspace
Connect-Maester -Service GoogleWorkspace -ServiceSetting @{
    GoogleWorkspace = @{ AdminEmail = 'admin@contoso.com'; Credential = $key }
}
```

1. `-Service` is no longer a fixed `ValidateSet`. It accepts built-in names and the
   services of installed connectors, with tab completion for both and a clear error
   for an unknown name. `-Service All` keeps its 3.0 meaning and does not include
   connectors; they are always named, like `ActiveDirectory` and `GitHub` today.
2. Settings for each connector are gathered in this order, last wins: the config
   file's `Connections.<Service>` section (non-secret values only),
   environment variables `MAESTER_<SERVICE>_<SETTING>`, then `-ServiceSetting`.
   A secret setting (`[securestring]`, `[pscredential]`, or a name ending in
   `Secret`, `Key`, `Token` or `Credential`) is refused from the config file. Values can
   reference a SecretManagement vault: `"Credential": "vault:GwsKey"`.
3. Connect-Maester calls the connector's `Connect` inside the pack, and adds a row to the summary table it already prints:
   `Google Workspace  Connected  contoso.com (C01abc)`, or `Failed` with the error
   summary, or `Not installed` when no installed pack provides the service.
4. `Disconnect-Maester` calls each connector's `Disconnect`. `Test-MtConnection
   -Service GoogleWorkspace` and `Get-MtTenantContext` call `Test` and `Describe`.

### 6.3 What the engine does with it

The 3.0 service registry (`assets/MaesterServiceRegistry.psd1`) becomes layered: the
built-in entries, then one entry per installed connector with `Probe` pointing at the
connector's `Test` function. Everything 3.0 already does with a service then works for
pack services unchanged: `[MaesterTest(Service = 'GoogleWorkspace')]` validates, the
gate gives `Skipped`/`ServiceNotConnected` (or `NotRun`/`OptInServiceNotConnected`
when the connector says `OptIn`), and `ServiceNotRegistered` covers a test whose pack
is missing.

- **Service names** are unique across built-ins and listed connectors. The publisher
  claims the service names its connectors provide at its first index, as it claims its
  code (section 4.5), and a pack can also use another pack's service by depending on
  it. Two installed packs that provide the same service
  are an install-time error naming both.
- **Parameter kinds** (3.0 section 3.4): a pack can add kinds under its own prefix
  (`GoogleWorkspace.OrgUnit`) for test parameters, so a UI can offer a picker.
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

## 7. Discovery, the index and hosting

### 7.1 Architecture

```text
 Install-MtPack ──install event──▶ Worker  packs.maester.dev/api/v1/events
                                     │  dedupe, rate limit ─▶ D1 (daily installs, queue)
                                     │  repository_dispatch, throttled per repository
                                     ▼
       GitHub Actions in maester365/packs-index (public repository: free minutes)
         fetch ▶ validate ▶ scan ▶ risk level ▶ listing JSON ▶ static site build
                                     │  wrangler deploy
                                     ▼
 Browser, Find-MtPack ◀── packs.maester.dev
                           static assets: pages, index.json, blocklist.json, per-pack JSON
                           Worker: /api/v1/stats, /api/v1/search, /api/v1/events
```

Everything that can be a static file is one, because Cloudflare serves static assets
free and without limit. The Worker does only three things: accept install events,
serve install counts, and (once the index is too big for one file) search.

### 7.2 From install to listing

1. **Install.** `Install-MtPack owner/repo` downloads the archive anonymously. If the
   GitHub API says the repository is public, the client posts an event to
   `/api/v1/events`: source (`github.com/owner/repo`), folder, commit, pack `Id`,
   Maester version, a random installation ID, and whether it ran in CI. It is fire and
   forget with a two-second timeout. `Restore-MtPack` sends a lighter event that counts
   as "active in CI", not as an install.
2. **Worker.** Checks the event's shape, applies a per-client rate limit, and writes
   at most one row per pack, installation and day, and one per pack, hashed IP and day
   (section 7.6). If the repository or commit is new, it adds it to a queue table and
   fires a `repository_dispatch` at the index repository, at most once per repository
   every ten minutes, with a GitHub App token scoped to that one repository.
3. **Index.** A workflow in the public `maester365/packs-index` repository runs on
   that dispatch and every 30 minutes on a schedule. For each queued repository and
   commit, **ignoring everything the client claimed except the repository name**, it:
   - looks the repository up through the GitHub API (numeric ID, public, owner account
     age, tags, organisation verification);
   - downloads the archive for the commit itself and computes the digest. The digest is
     the cache key: the same content is never scanned twice;
   - runs validation and every scan (section 9.6) and assigns the risk level;
   - writes the listing: manifest, README, test catalog (read statically, as 3.0's
     catalog is), connector settings, `Uses`, scan results, binaries, risk level,
     badges, digest.

   A version that fails is recorded with its reasons and not listed; the publisher
   sees why (section 7.7).
4. **New versions.** The scheduled run also asks GitHub, in one GraphQL query per
   batch, for new release tags on listed repositories, so a new version is scanned
   before anyone installs it.
5. **Publish.** The workflow commits the listings to the index repository (a public
   history of every listing and takedown), builds the static site, and deploys it with
   `wrangler`: pages, `index.json` (signed), per-pack JSON, `codes.json` (who holds
   each code and service name) and `blocklist.json` (signed).
6. **Show.** Pages fetch install counts from `/api/v1/stats` (edge-cached for five
   minutes). `Find-MtPack` reads `index.json` and searches it locally.

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
indexer picks up, for publishers who want a listing before anyone installs.

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
- The CLI sends one event per install, never one per run.
- Search runs in the client over `index.json` until that file is too large.
- Counts are edge-cached for five minutes, so most page views never reach D1.
- A digest is scanned once; only new commits cost workflow time, and that time is free.
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

The index does not open issues or post statuses on publishers' repositories: that would
need write access to them.

| Reason | What the publisher sees (examples) | Fix |
| --- | --- | --- |
| `CodeMismatch` | Test IDs must start with `MP.CNT.`, the code contoso holds. 3 tests use `MP.CTO.`: `MP.CTO.0001`, `MP.CTO.0002`, `MP.CTO.0003`. | Rename the IDs, or correct `Code` in the manifest |
| `CodeTaken` | The code `OKTA` is held by fabrikam. contoso has no code yet. | Pick a free code (`Find-MtPack -Code`) |
| `CodeReserved` | `MS` is a reserved code. | Pick another code |
| `CodeMissing` | `maester-pack.json` has no `Code`. | Add one |
| `DuplicateTestId` | `MP.CNT.0001` is already used by contoso/maester-okta. | Renumber, or add a segment per pack (`MP.CNT.GWS.0001`) |
| `ServiceTaken` | The service name `GoogleWorkspace` is held by maester365. | Depend on that connector pack, or rename the service |
| `InvalidPack` | `tests/Test.MP.CNT.0004.ps1:12`: a statement outside a function runs when the file loads. | Fix the file and line named |
| `UndeclaredReach` | `connectors/GoogleWorkspace.ps1:40` calls `api.example.com`, which `Uses.Network` does not declare. | Declare it, or remove the call |
| `DuplicateContent` | Same content as fabrikam/okta-pack (digest `sha256:91c4…`). | Publish your own work |
| `OwnerTooNew` | The contoso account is 12 days old; it can be listed from 25 Oct 2026. | Nothing: indexed again automatically |
| `DailyLimit` | contoso already listed a new pack today. | Nothing: listed tomorrow |
| `NoRelease` | Indexed from the default branch: code `CNT` is now held by contoso. Tag a release to be listed. | Tag a release |
| `Blocked` | Blocked: advisory MPA-2026-0003. | See the advisory; appeal in the index repository |

A repository the index cannot see (private, or not found) has no status page, and
`Test-MtPack -Remote` says so.

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
| `/{owner}/{repo}[/{folder}]` | **Pack** | Header with badges, risk level, publisher, description and platforms; install box with PowerShell, maester-action and lock file tabs; tabs: **Overview** (the README, sanitised), **Tests** (ID, title, severity, service, each linking to its page), **Connector** (what it connects to, how to sign in, the settings table with secret markers and environment variable names, what it needs on the platform), **Security** (risk level and why, every compiled file with hash and signer, each scan's result, declared `Uses` against what was found, repository signals, repository ID, advisories), **Versions** (tag, commit, date, digest, risk level, changes to `Uses`); a sidebar with installs, version, first seen, last release, licence, required Maester version, GitHub stars and "Report this pack" |
| `/{owner}/{repo}/tests/{id}` | **Test** | The test's Markdown (description, remediation) and its attribute data |
| `/{owner}` | **Publisher** | Badges, the code and service names the publisher holds, packs, security contact |
| `/status/{owner}/{repo}` | **Indexing status** | Each version the index has seen: listed, or not listed with every reason and its fix (section 7.7) |
| `/official`, `/platform/{service}`, `/category/{slug}` | **Lists** | Filtered leaderboards |
| `/advisories[/{id}]` | **Advisories** | Blocked packs and versions, what happened, what to do |
| `/publish` | **Publishing guide** | The steps of section 10.3, the rules of section 4.3, risk levels and badges |
| `/security` | **Security model** | Section 9 in plain words, for admins and their security reviewers |
| `/b/{owner}/{repo}.svg` | **Badge** | Risk level and installs, for a pack's README |
| `/api/v1/...` | **API** | `events` (POST), `stats`, `search` |

A blocked pack's page keeps its URL, shows the advisory at the top and removes the
install command.

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
| Repository takeover | Owner renames or deletes the repo; someone re-creates the old name | The index and lock file record GitHub's numeric repository ID; a changed ID freezes the listing and fails restores |
| Fake installs | Inflating installs to push a pack up the leaderboard | Section 7.6; popularity never changes a risk level or a badge |
| Code that runs on load | `using module`, class definitions, top-level statements | Function-only files are a validation rule (section 4.3); no install scripts exist |
| Dependency attack | A typosquatted or compromised PowerShell Gallery module | Exact version pins; package hash in the lock file; modules shown in the prompt and scanned |
| Local tampering | Malware edits a pack in the store | Read-only files; digest checked on every load |
| Report as a channel | A result embeds a remote image whose URL carries data | The report already sanitises Markdown (DOMPurify); pack rows also lose remote images and show link targets |
| Secrets in results | A pack writes a token into a result | Results are scanned for token patterns before writing, as for built-ins |
| Index compromise | A forged listing or a removed blocklist entry | The index is a public repository with protected branches and review; listings and blocklist are signed and verified by the client |

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
| **Microsoft MVP** | The GitHub account that owns the repository is listed on a current, public Microsoft MVP profile | A weekly sync from the public MVP profile directory, matching the GitHub link MVPs add to their profile (the same unauthenticated endpoints the newsletter project already syncs) |
| **GitHub-verified organisation** | The owning organisation has verified its domain with GitHub | GitHub's organisation API (`is_verified`) |

The MVP badge is best-effort, as decided: the directory API is undocumented, and the
link is self-declared by the MVP. A badge never changes a risk level. A publisher verification
programme (signed releases, reviews, a Verified badge) is out of scope for v1 and
listed for phase 3.

### 9.6 Risk levels and scanning

| Level | What it means | Install | Shown as |
| --- | --- | --- | --- |
| **Low** | Text files only (PowerShell, Markdown, JSON); every scan passed | The normal prompt | Green "Low risk" |
| **Medium** | Text only, with findings worth reading: dynamic code (`Invoke-Expression`, `[scriptblock]::Create`, inline `Add-Type`), URLs built at run time, declared tenant writes, process start, PowerShell Gallery dependencies | The prompt lists the findings; `-AcceptRisk Medium` without a console | Amber "Medium risk" |
| **High** | Compiled code, archives, or content that cannot be scanned (encoded or obfuscated); or a scan could not complete | Named file by file; typed confirmation; `-AcceptRisk High` without a console | Red "High risk: install only if you trust the publisher" |
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
  "Index": "https://packs.maester.dev/index.json"
}
```

The policy is read from the run config, from `MAESTER_PACK_POLICY`, or from a
machine-wide file that device management can deploy, and the strictest value wins. It
applies at install, restore and run. `RequireBadge` can demand `Official` or
`MicrosoftMvp`. `Index` can point at an internal mirror: the index and archives are
static files, so an organisation, or an air-gapped network, can host a copy.

### 9.8 Revocation

- The index publishes a **signed blocklist** (`blocklist.json`) of pack IDs or
  repository IDs, version ranges or digests, a severity and an advisory link. It is
  signed with an ECDSA P-256 key whose public half ships in the module (.NET verifies
  it with no extra library), rotated through module releases.
- `Invoke-Maester`, `Restore-MtPack` and `Install-MtPack` fetch it with a short
  timeout and cache it for an hour. A blocked pack does not load: its tests give
  `NotRun` rows with reason `PackBlocked`, a warning names the advisory, and
  `Get-MtPack` shows it. Offline runs use the cached list and warn when it is older
  than seven days; policy can make that an error.
- **A block stops a pack from running; it never deletes it.** VS Code's kill switch
  once uninstalled a legitimate extension by mistake for two weeks; here removing the
  entry undoes a false positive at the next run. An entry can also be `Warn` (runs,
  with the advisory shown) for something suspicious but unproven.
- Reports come in through a "Report this pack" link on every page (a GitHub issue) and
  the project's security contact. Maintainers can block within hours, notify the
  publisher, and publish an advisory. A publisher can appeal in the index repository.

### 9.9 Privacy of the install event

The install event carries the pack source, commit, pack ID, Maester version, a random
installation ID and whether it ran in CI. The Worker hashes the IP with a daily salt
for deduplication and stores neither the IP nor any tenant, user or machine
identifier. Nothing is sent for a source that needed credentials to download (a
private repository). `MAESTER_TELEMETRY_OPTOUT=1`, `DO_NOT_TRACK=1` or config
`Telemetry.Disabled` turns it off.

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

1. `New-MtPack -Id contoso.google-workspace -Code CNT -Service GoogleWorkspace` scaffolds the
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
| Pack loader | Read `maester-pack.json`; load suites, helpers and connectors into one private module per pack; fill `Package` on rows | 1 |
| Install | `Install-`, `Restore-`, `Update-`, `Uninstall-`, `Get-MtPack`; GitHub archive download without git; digest; lock file; store; risk acceptance | 1 |
| Config | `Packs`, `Connections` and `PackPolicy` sections in the 3.0 config schema and resolver | 1 |
| Validation | `Test-MtPack` (section 4.3 rules, the `MP.<code>` ID rule, local scans and risk level); `New-MtPack` scaffold; a template repository | 1 |
| Test schema | `MP.` added to the reserved prefixes, so custom tests written before packs ship get the warning; this one line can land in 3.0 | 1 (or 3.0) |
| Connectors | Layered service registry; `Set-`/`Get-`/`Clear-MtConnectionState`; `Get-MtConnector`; `Connect-Maester -Service` opened up with `-ServiceSetting`; `Disconnect-Maester`, `Test-MtConnection`, `Get-MtTenantContext` dispatch to connectors; `Renew` before tests | 1 |
| Report | `Package` filter and group; remote images stripped for pack rows | 1 |
| maester-action | `restore_packs` input; pack environment variables passed through | 1 |
| Index client | `Find-MtPack`; signed index and blocklist verification; install event | 2 |
| Isolation | Container partitions per pack for hosts that can run containers | 3 |
| Built-in connectors | GitHub and Active Directory on the connector contract | later |

Outside the module (phase 2): the `maester365/packs-index` repository and its
workflows and scanners, the `maester365/pack-scan` reusable action, the Worker and D1
database, the static site, the MVP directory sync, a GitHub App for the dispatch, and
the signing key.

## 12. Phases

1. **Phase 1, packs without the marketplace (3.1).** The format, GitHub install with
   the lock file, connectors and `Connect-Maester` dispatch, `New-` and `Test-MtPack`,
   the template, maester-action restore. Packs run in-process. Every install is
   "unlisted" and gets the local scan and risk level. The first official pack is
   Google Workspace, against the CISA SCuBA Google Workspace baselines (the ones ScubaGoggles implements), which proves the connector contract
   with both a browser sign-in and a service account; the licence of any code reused
   needs checking.
2. **Phase 2, Maester Packs.** The Worker and D1, the index workflows and scanners,
   risk levels and badges, the signed index and blocklist, `Find-MtPack`, and
   packs.maester.dev. The public launch waits for the blocklist, the cooldown and the
   risk levels, because listing community code without them would ask users to trust
   it blindly.
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

### Still open

- **Setup you would own:** a GitHub App for the Worker's dispatch, the blocklist
  signing key, and the Cloudflare account and zone settings.

## 15. Not yet verified

- **Cloudflare details:** that Bot Fight Mode cannot be scoped per path on the free
  plan; whether the Workers rate-limiting binding is included on the free plan; and the
  number of free WAF rate-limiting rules. Pricing in section 7.5 is from Cloudflare's
  Workers pricing page on 2026-10-07.
- **The MVP directory API** is undocumented and may change or rate-limit.
- **GitHub Models' free tier** and VirusTotal's public API terms for a non-commercial
  open-source index need confirming before either is relied on.
- **Static rules for load-time execution:** that function-only files plus the listed
  bans cover every way a PowerShell file can run code when dot-sourced.
- **Scanner quality:** false-positive rates of the pack rules on real community code
  (the built-in checks are the first corpus).
- **Container isolation** (phase 3): access-token sign-in for each Microsoft module
  inside a container, and renewal between tests.
- **The skills.sh mechanics** are taken from its public CLI source (commit `958f4b7`)
  and site on 2026-10-07 and may change; its server code is not public, so the
  deduplication and trending formulas are as documented, not as read. The facts about
  Steampipe, Terraform, VS Code, npm and ScubaGoggles are from their documentation on
  the same date.

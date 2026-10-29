# Design: Maester Packs in any language

> **Status: DRAFT.** A proposal, not built. Maester 3.0 runs only PowerShell packs: a manifest whose `Runtime`
> is anything but `Script`, or whose `Catalog` is an object, is refused with `RuntimeNotSupported`
> (`powershell/internal/packs/Read-MtPackManifest.ps1`). This document describes what lifts that refusal. It
> records the owner's rulings of 2026-10-16 and was first reviewed as PR #2396, against the earlier packs
> design draft. Section numbers start at 4.8 because the code refers to "section 4.8".

How packs work today is described in the packs documentation:
[Maester Packs](../../website/docs/packs/index.md), [Writing a pack](../../website/docs/packs/writing-a-pack.md)
and [Pack security](../../website/docs/packs/security.md). This proposal only adds to them.

## 4.8 Packs in any language

A pack does not have to be PowerShell. Anyone can write checks in Python, TypeScript, Go, Rust, .NET or
anything else that can read and write JSON, and Maester still owns discovery, selection, the gates,
parameters, timeouts, result rows and the report.

### 4.8.1 One protocol, five runtime kinds

PowerShell packs load into Maester's runspace, into a private module. Nothing else can, so a pack in any other
language runs as **one child process per pack**, started by Maester and spoken to over stdin and stdout with
the **runner protocol** (4.8.3). The protocol is the contract; a language is only a convenience on top of it.
Maester knows a small number of **runtime kinds**, and each answers two questions: how to start the runner,
and how to get what it needs onto the machine without running publisher code and with every byte pinned.

| Kind | For | Starts as | Gets onto the machine by |
| --- | --- | --- | --- |
| **Script** | PowerShell (today's packs) | One private module in Maester's runspace | The pack's files |
| **Python** | Python | `<env>/python -I -m <Entry>` | `uv sync --frozen --no-build` from the pack's `uv.lock` (4.8.4) |
| **Node** | TypeScript and JavaScript | `node <Entry>` from the publisher's compiled `dist/` | `npm ci --ignore-scripts` from `package-lock.json` (4.8.4) |
| **Binary** | Anything compiled: Go, Rust, .NET, C++, a single-file Node or Python build, a vendor's executable | The executable for this OS and CPU | A GitHub release asset, checked against the SHA-256 in the manifest (4.8.5) |
| **Container** | Anything, including tools with heavy system dependencies | `docker run -i --rm <image>@sha256:…` (or Podman) | Pulled by digest (4.8.5) |

A new interpreted language later (Deno, Ruby, Java) is one more row: how to find the interpreter, how to
restore its lock with install scripts off, and how to start the runner. The engine, the protocol, the catalog,
the loader gate and the report do not change. Anything without a row ships as Binary or Container.

The manifest gains two top-level keys:

```json
"Catalog": "catalog.json",
"Runtime": {
  "Kind": "Python",
  "Protocol": 1,
  "RequiresPython": ">=3.11,<3.15",
  "Lock": "uv.lock",
  "Entry": "gws_checks"
}
```

`Runtime` and `Catalog` are keys an older Maester must refuse rather than ignore: an older client that ignored
`Runtime` would drop every test of the pack without saying why. Maester 3.0 already refuses them.

### 4.8.2 Discovery stays static: the catalog

PowerShell cannot read a Python decorator from an AST, so a non-Script pack lists its tests in a committed
**`catalog.json`**: one entry per test with the same fields as `[MaesterTest(...)]`, validated against the same
schema table (published as JSON so every language shares it), plus the usual `Test.<ID>.md` files. Discovery,
`-DryRun`, `Get-MtTest`, selection, the `MP.<Code>` rule, reserved tags and the taxonomy checks read the catalog
and need no interpreter. A Script pack may use a catalog too, for rule catalogs where many rules share one
evaluator.

- **Each SDK generates the catalog without running the pack.** The Python SDK reads `@maester_test(...)`
  decorators with Python's `ast` module and never imports the package; the TypeScript SDK reads decorators with
  the TypeScript compiler API. Decorator arguments must be literals, as attribute values must be static in
  PowerShell.
- **Catalog and code must agree.** `Test-MtPack` and the pack index run the SDK's reader and fail validation on
  any difference. For Binary and Container packs, whose source may not be readable, the index runs the
  runner's `list` message in a sandboxed job with no secrets and compares.
- **At run time** the runner reports the IDs it registered. Results are accepted only for IDs in the catalog; a
  catalog ID the runner did not register gets an `Error` row with reason `CatalogMismatch`.

A Python test, as the SDK would have it:

```python
@maester_test(id="MP.CNT.1201", title="No guest has a directory role",
              severity="High", service=["Graph"], product="entra")
def no_guest_admins(ctx):
    roles = ctx.graph.get("directoryRoles", query={"$expand": "members"})
    member_ids = {m["id"] for r in roles for m in r["members"]
                  if m.get("@odata.type") == "#microsoft.graph.user"}
    guests = [u for u in ctx.graph.get_by_ids(member_ids, select=["id", "displayName", "userType"])
              if u.get("userType") == "Guest"]
    ctx.detail(table(guests))
    return not guests
```

The example decides who is a guest from `userType`, not from `#EXT#` in the user principal name: an account
converted to a guest can keep an ordinary UPN, and an external member can have `#EXT#`. The built-in checks do
the same (`powershell/internal/checks/maester/entra/Test-MtPrivPermanentDirectoryRole.ps1`).

### 4.8.3 The runner protocol

- **Transport.** JSON lines over stdin and stdout, with requests correlated by `id` in both directions (the
  shape LSP and MCP use). stderr is kept as `Diagnostics` and never parsed. SDKs redirect ordinary console
  output to the log channel so a stray print cannot corrupt the stream. No ports, so no firewall prompts and no
  authentication between processes.
- **Lifetime.** One runner per pack per session, started on first use (by `Connect-Maester` for a connector, by
  `Invoke-Maester` for tests) and kept until `Disconnect-Maester`, the end of the run or module removal.
  Interpreter start-up and library imports cost far more than most tests, so a process per test is not used.
- **Nothing secret on the command line or in the environment.** Settings and secrets travel only inside
  messages. The runner gets a cleaned environment: `PATH`, locale, temp folders, proxy and CA settings, the
  variables the runtime needs, and the variables named in the pack's connector `Environment` list; CI secrets
  and other packs' `MAESTER_*` variables are left out.
- **Tests run one at a time, in catalog order**, like every 3.0 test.

Host to runner:

| Message | When | Carries |
| --- | --- | --- |
| `initialize` | Once per runner | Protocol version, Maester version, the pack's config section, the output folder, the tenant context, the kept connection state |
| `connector.connect`, `.test`, `.describe`, `.renew`, `.disconnect` | The connector hooks | Settings gathered from config, `MAESTER_*` variables and `-ServiceSetting` |
| `collect` / `release` | Once before the first test and once at the end, when the pack uses Collect | Selected test IDs, a deadline |
| `instances` | For a family, in the execute stage | Family ID and bound parameters |
| `run` | Once per selected test or instance | Test ID, instance, bound parameters, deadline |
| `list` / `shutdown` | Validation; end of use | |

A `run` answer carries the outcome in the 3.0 test contract: `passed`, `failed`, `skipped` with a skip code and
reason, `investigate`, `noresult` or `error`, plus the detail Markdown and affected objects that
`Add-MtTestResultDetail` takes. The engine turns it into a row with the same code that builds native rows, so
severity overrides, titles, `Source = Custom`, the `Package` field and the report's Packs section are shared
with Script packs. `Format` stays `Native`; `Package.Runtime` names the kind.

Runner to host, while a test runs:

| Callback | Host does | Rules |
| --- | --- | --- |
| `graph.request` | `Invoke-MtGraphRequest` | Refused unless `Graph` is in `Uses.Services`. `GET` is allowed. Any other method is refused unless it is on the host's list of read-only operations (below) or the pack declares it in `Uses.TenantWrites` |
| `azure.request` | `Invoke-MtAzureRequest` | The same rules for `Azure` |
| `connection.get`, `connection.set` | `Get-` / `Set-MtConnectionState` | Only the pack's own services and those it declares from a required connector pack |
| `log` | Verbose, information or warning stream | Text cleaned as for every pack's output |
| `prompt` | Shows a device code or URL | Only during an interactive `connector.connect` |

- **Read-only operations that use POST.** Some reads are POSTs: Defender advanced hunting
  (`POST /security/runHuntingQuery`, used by `Invoke-MtGraphSecurityQuery`) and Azure Resource Graph
  (`POST /providers/Microsoft.ResourceGraph/resources`, used by `Invoke-MtAzureResourceGraphRequest`). Refusing
  every non-GET would force such a pack to declare a write and become High risk. Maester therefore keeps the
  list of read-only POST operations itself, as method and path pairs in the module, never taken from the
  manifest. A request on the list is allowed like a GET; anything else that is not a GET still needs
  `Uses.TenantWrites`, and an undeclared write is refused at the boundary. Adding an operation to the list is a
  Maester change, reviewed like any other.
- **Microsoft calls go back through Maester.** No token leaves PowerShell, the Graph cache and throttling budget
  are shared with the built-in checks, and the rule that packs reach Microsoft services only through Maester's
  commands holds unchanged. Because the host sees every request, it can enforce `Uses` at the boundary instead
  of only scanning for it.
- **Only Graph and Azure REST are brokered.** Exchange Online, Security & Compliance, Teams and SharePoint
  sessions are cmdlets bound to one runspace, and brokering arbitrary cmdlets would be a remote-execution
  channel. A short allowlist of read-only `Get-*` cmdlets can come later. A pack that needs its own Microsoft
  client wraps it in its own connector and declares it.
- **Connectors in any language.** A connector's settings are declared in its manifest entry (`Settings`:
  `Name`, `Type`, `Secret`, `Mandatory`, `Help`), since Maester cannot read a Python or Go parameter list
  statically. `Get-MtConnector`, tab completion, the `MAESTER_<SERVICE>_<SETTING>` variables and the refusal of
  secrets in the config file work from that list.
- **Connection state survives a restart.** The runner returns its state (a token and its expiry, a refresh
  token) as an opaque value the host keeps in memory with `Set-MtConnectionState` and passes back in
  `initialize`. It is never written to disk or into the result.
- **Timeouts and crashes.** At a test's deadline the host kills the runner (on Windows through a job object, so
  its children go too), records `Error`/`Timeout`, restarts it with the kept state and carries on. An
  unexpected exit gives the current test `Error`/`TestError` with the tail of stderr and the same restart; after
  a second crash the pack's remaining tests get `Error` rows with reason `RuntimeFailed`, and the run continues.

### 4.8.4 Dependencies

Maester verifies dependencies; the language's own installer installs them. Maester never resolves versions and
never runs pip or an npm install script. **No installer runs without the user's opt-in, wherever it runs**:
`Install-MtPack`, `Update-MtPack`, `Restore-MtPack` and maester-action all print the command they would run and
run it only with that opt-in.

- **The opt-in.** `-InstallDependencies` on `Install-MtPack`, `Update-MtPack` and `Restore-MtPack`, or
  `Packs.InstallDependencies: true` in the config file, which is how a CI run gives it (maester-action reads the
  config file, and also takes an `install-dependencies` input that sets it). Without it, each command prints the
  exact command it would run for each pack and installs nothing.
- **Python.** The pack ships `pyproject.toml` and a universal, hash-pinned `uv.lock` (or a PEP 751
  `pylock.toml`). With the opt-in, Maester runs `uv sync --frozen --no-build --no-dev --compile-bytecode` into a
  virtual environment inside the pack's folder in the store. `--frozen` installs exactly the lock without
  resolving, uv checks every hash, and `--no-build` refuses source distributions, so only wheels are installed
  and no package code runs. The command is generated by Maester from the manifest, never taken from publisher
  text. uv can also install the interpreter that `RequiresPython` asks for.
- **Node.** The pack ships its compiled `dist/` and `package-lock.json`; with the opt-in Maester runs
  `npm ci --ignore-scripts --omit=dev`, so npm checks the lock's `integrity` hashes and no install script runs.
  Maester never runs the TypeScript compiler.
- **Binary and Container.** Nothing to install beyond the asset or image itself, which `Install-MtPack` fetches
  and checks.
- **The installed environment is checked, not only the lock.** The language lock is inside the pack, so the pack
  digest covers it, but a lock says nothing about files someone changes in `site-packages` or `node_modules`
  after the install, and read-only permissions can be undone by the owner. So, right after the installer
  finishes, Maester records an **inventory** of the environment: the relative path and SHA-256 of every file in
  it, stored in the pack's lock entry next to the hash of the language lock it was built from. Before it starts a
  runner, the loader gate hashes the environment again and compares it with the inventory: a file added,
  removed or changed, or an inventory built from a different language lock, refuses the pack with
  `EnvironmentChanged` and the command to rebuild it. This is the same check `Uses.Modules` gets today, where
  Maester checks a saved module's files before every load. The runner starts with `python -I` (or `node` with
  no `NODE_OPTIONS` and no `NODE_PATH`), so nothing outside the environment is loaded in its place.
  `maester-sdk` is itself a pinned dependency, and a runner whose protocol version Maester does not speak is
  refused with a clear error.
- **Restore and CI.** `Restore-MtPack` and maester-action handle every non-Script pack in the lock file the same
  way, with the same opt-in. Without the opt-in, or without uv, npm or Docker on the machine, the pack's tests
  are skipped with reason `RuntimeNotAvailable` and the command to run, and the run continues, as
  `PesterNotAvailable` does today.
- **Bring your own environment.** `Packs[].Interpreter` (or `Packs[].Image`) points at an environment the user
  built from a corporate mirror, conda or their own image. Maester cannot vouch for it, so the pack is labelled
  **Externally managed environment** in the prompt, `Get-MtPack` and the report, has no inventory, and
  `PackPolicy.AllowExternalEnvironments` can forbid it.
- **Air-gapped.** `Save-MtPack` adds the locked wheels, npm tarballs, binary assets or image archives to the
  bundle, and `Restore-MtPack -Source` installs from it offline, with the same opt-in and the same inventory.

### 4.8.5 Binary and Container packs

```json
"Runtime": {
  "Kind": "Binary",
  "Protocol": 1,
  "Artifacts": {
    "windows-x64": { "Asset": "contoso-gws-windows-x64.exe", "Sha256": "4f1c…" },
    "linux-x64":   { "Asset": "contoso-gws-linux-x64",       "Sha256": "9a20…" },
    "osx-arm64":   { "Asset": "contoso-gws-osx-arm64",       "Sha256": "c77e…" }
  }
}
```

- **Binaries come from the release, not the repository.** `Install-MtPack` downloads only the asset for this
  platform (all of them for `Save-MtPack`) from the release of the pinned commit and refuses any file whose hash
  differs from the manifest, which the pack digest covers. The loader gate checks the hash again before every
  start.
- **Unsupported platforms** use the existing platform gate: a Binary pack's tests take the platforms of its
  `Artifacts`, and the engine gives `Skipped`/`PlatformMismatch` elsewhere.
- **Container packs** name an image by digest (`"Image": "ghcr.io/contoso/gws-checks@sha256:…"`) and run with
  `docker run -i --rm`, the cleaned environment and no mounts beyond the run's output folder. The same runner in
  the same container can later become an isolation boundary for packs that need one.
- **Build provenance lowers the risk of compiled code.** A binary or image with a valid GitHub artifact
  attestation (Sigstore build provenance) showing it was built by a workflow in the pack's own repository from
  the pinned commit is **Medium**, and the listing says "Built from source at 3f9c2e1 by
  .github/workflows/release.yml"; its source is scanned like any other pack. Without provenance it stays
  **High**.
- **Locked-down Windows:** App Control blocks unsigned executables, so an unsigned Binary pack does not run
  there, and `Install-MtPack` says so.

### 4.8.6 Tools that will never speak the protocol

Existing tools (a vendor CLI, ScubaGoggles, a scanner) are covered without any code from their authors, by
**Import** (the tool runs as its own step and writes a file), **Collect** (Maester runs the tool once at the
start of the run, with a command line the manifest declares as an array, never a shell string) and an
**adapter** that maps the file to rows:

- **`MaesterResults`**: a small published JSON schema (`[{ "id": "MP.CNT.1001", "outcome": "failed", "detail": "…" }]`)
  that any tool in any language can write.
- **`SARIF`**: the OASIS format most security scanners write. Each `ruleId` maps to a catalog ID. The outcome
  comes from the result's `kind`, which defaults to `fail` when it is absent: `pass` is Passed, `fail` is
  Failed, `review` and `open` are Investigate, `notApplicable` is Skipped and `informational` is NoResult. The
  result's `level` (`error`, `warning`, `note`, `none`) is severity, not outcome: it is kept as the row's
  reported severity and shown in the detail, so a `fail` with `level: note` is still a failed check.
  Locations become the detail table.
- **`JUnit`**: for tools that write test results.

Results are accepted only for catalog IDs, an ID the file does not mention is `Skipped`/`NotCollected`, and a
file older than the pack's maximum age is rejected.

### 4.8.7 SDKs and conformance

- The protocol is published as a versioned specification with JSON Schemas.
- maester365 publishes and maintains SDKs for **Python** (`maester-sdk` on PyPI) and **TypeScript** (on npm).
  Each mirrors the 3.0 test contract: return `True`/`False`, `ctx.skip()`, `ctx.investigate()`,
  `ctx.detail(markdown)`, `ctx.graph.get()`, families with an instance source. Other languages are left to the
  community.
- **`Test-MtPack -Conformance`** starts a runner against a fake host and checks every message, timeouts, crash
  handling and catalog agreement, so someone can write a runner in a language nobody planned for.
- Until the runtimes ship, a Script pack can shell out to a program and return its answer; that works today, at
  the cost of a process per test and no shared session.

### 4.8.8 Where non-Script packs run

Locally on Windows, macOS and Linux, in maester-action (which adds uv or Node when the lock file has such packs),
Azure DevOps and containers. Azure Automation's PowerShell 7.4 sandbox very likely cannot start a Python or
Node process, so those tests would be skipped with `RuntimeNotAvailable` there. That is not yet verified.

## Review history

PR #2396 proposed this section for the earlier packs design draft. Its automated review raised five points,
all taken here:

1. A marker holding the lock's hash did not prove the installed files were unchanged. 4.8.4 now records an
   inventory of the installed environment and checks it before every start.
2. Refusing every non-GET request would have made read-only POST queries (advanced hunting, Azure Resource
   Graph) declare writes. 4.8.3 adds a host-owned list of read-only operations.
3. Restore and CI ran dependency installers without the opt-in that install requires. 4.8.4 now applies the
   same opt-in everywhere.
4. The overview's Python example found guests by `#EXT#` in the UPN. The example in 4.8.2 uses `userType`.
5. SARIF outcomes were mapped from `level`. 4.8.6 maps them from `kind` and keeps `level` as severity.

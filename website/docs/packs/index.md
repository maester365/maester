---
title: Maester Packs
description: What a Maester Pack is, how public and private packs differ, and how to install, run and connect them.
sidebar:
  order: 1
---

# Maester Packs

## What is a pack?

A pack is a set of extra tests for Maester that someone else wrote and shares. Maester ships with its own checks;
a pack adds more, so one run can also cover another product, a benchmark, or the rules of one organisation.

A pack is a folder, usually a GitHub repository, that holds:

- **tests**, written the same way as Maester's own;
- **helpers** the tests call;
- optionally a **connector** to a service Maester does not know, such as Google Workspace or Okta.

Installing a pack adds its tests to your project. A run includes them when you name the pack with `-Pack` (or every
installed pack with `-AllPacks`), and its results appear in the report beside Maester's own, marked as the pack's.

```powershell
Install-MtPack contoso/maester-google-workspace
Connect-Maester -Service Graph, CNT.GoogleWorkspace
Invoke-Maester -Pack CNT
```

A pack is public or private, depending on the repository it lives in. Some packs also ship with Maester: they need
no install and run as soon as they are turned on (see [Packs that ship with Maester](#packs-that-ship-with-maester)).

## Public packs

A public pack lives in a public GitHub repository, so anyone can install it with `Install-MtPack <owner>/<repo>`.
The publisher does not need to register it anywhere or ask anyone: a public repository with a
[valid pack](./writing-a-pack.md) and a release is enough.

To help people find a pack, its publisher can list it on a pack index, a site that collects packs and shows a page
for each one. [packs.maester.cloud](https://packs.maester.cloud/) is the index the Maester team runs: it reads and
scans every pack before listing it, and shows what the pack checks, what it can reach and its risk. Listing is
optional. An index only lists a pack: you still install it straight from the publisher's repository, and Maester
runs the same [checks](./security.md) at install wherever you found it.

When you install a public pack, Maester sends one anonymous event (the pack's source and commit, and a random
installation ID) so installs can be counted. Set `MAESTER_DISABLE_TELEMETRY` to `1` to turn that off.

## Private packs

A private pack lives in a private or internal GitHub repository. Only people who can read that repository can
install it, which makes it the way to share tests inside one company: checks for your own policies, naming rules or
internal systems that should not be published. Anyone you give access to the repository, such as a partner or a
customer, can install it as well.

Install it like any other pack. Maester reads a GitHub token from `GH_TOKEN` or `GITHUB_TOKEN` to reach the
repository. Set it only for the install, then remove it:

```powershell
$env:GH_TOKEN = gh auth token
try { Install-MtPack contoso/maester-internal-checks } finally { Remove-Item Env:GH_TOKEN }
```

:::caution[Keep the token out of your session]
Everything that runs in the session can read an environment variable, including the packs you run. Use a token
that can only read this one repository (a fine-grained token with read-only **Contents**), do not set it in your
profile, and remove it before `Invoke-Maester`. Running an installed pack does not need it: only
`Install-MtPack`, `Update-MtPack` and `Restore-MtPack` download from GitHub. A way to install without an environment variable is tracked in
[issue 2790](https://github.com/maester365/maester/issues/2790).
:::

A private pack goes through the same checks as a public one, and is pinned in the lock file the same way. What is
different:

- It is never listed on packs.maester.cloud, and cannot be published there.
- Nothing about it is sent to Maester: no install event, and run telemetry never names it.
- A pipeline needs the token too. In GitHub Actions the workflow's own `GITHUB_TOKEN` reads only the repository
  the workflow runs in, so a pack in another private repository needs a token that can read that repository.
  Give it to the restore step only, not to the whole job.

A pack can also be installed from a local folder (`Install-MtPack ./my-pack`), which suits a pack you are still
writing or one you keep outside GitHub. Nothing is sent for a local folder either.

## Installing a pack

`Install-MtPack` takes the pack's GitHub repository (`owner/repo`, `owner/repo/folder`, `owner/repo@ref` or a
github.com URL) or a local folder. Before anything is saved, Maester:

1. downloads the pack and reads it without running any of its code: its manifest, every file and what its
   scripts call;
2. checks that the release is at least 72 hours old (the [cooldown](./security.md#cooldown));
3. checks your [pack policy](./security.md#pack-policy) and the signed [blocklist](./security.md#blocklist);
4. saves the PowerShell Gallery modules the pack declares, at their exact versions, into its own store;
5. shows you what the pack can reach, its risk and anything the scan found, and asks you to approve it.

```text
  Google Workspace checks  contoso.google-workspace 1.2.0
  Source      github.com/contoso/maester-google-workspace @ 3f9c2e1 (ref v1.2.0)
  Publisher   contoso
  Adds        14 tests (MP.CNT.*) and the "Google Workspace" connector
  Reaches     CNT.GoogleWorkspace, admin.googleapis.com
  Microsoft   no extra Graph scopes
  Risk        LOW: text files only; no findings from the content checks
```

The approved files go into a read-only store under `~/.maester/packs` (or `MAESTER_PACK_HOME`), named by their
digest, and the pack is recorded in two files beside your `maester-config.json`:

- `maester-config.json` gets a `Packs` entry: `{ "Id": "contoso.google-workspace", "Source": "contoso/maester-google-workspace", "Version": "1.2.0" }`.
- `maester-packs.lock.json` records the commit, the digest of the files, the test IDs, the risk you accepted and
  the digest of every module.

Commit both. Without a project config, packs are installed for your user, in `~/.maester`.

| Command | What it does |
| --- | --- |
| `Install-MtPack <source>` | Installs a pack, after the checks above. `-Version` picks a release, `-IncludeRecent` one newer than the cooldown. |
| `Get-MtPack` | Lists the packs this folder runs and whether each can run (`Status`, `Reason`). |
| `Update-MtPack [<id>]` | Installs each pack's newest release that has met the cooldown, showing what changed since you approved it. |
| `Restore-MtPack` | Installs exactly what the lock file records, on another computer or in a pipeline. Nothing is asked: the lock file is the approval. |
| `Uninstall-MtPack <id>` | Removes the pack from the lock file and the config. |
| `Get-MtConnector` | Lists the services that installed packs connect to, and whether each is connected. |

### In a pipeline

Commit `maester-config.json` and `maester-packs.lock.json`, then restore before the run:

```powershell
Restore-MtPack
Invoke-Maester -AllPacks -NonInteractive
```

To install without a prompt, say which risk you accept: `Install-MtPack contoso/pack -NonInteractive -AcceptRisk Medium`.

## Running pack tests

Installing a pack does not add its tests to every run. `Invoke-Maester` runs an installed pack when you name it
with `-Pack` (by its code or ID), when `-TestId` names one of its tests, when you pass `-AllPacks`, or when the
config turns it on with `"Enabled": true`. A pack's tests have IDs `MP.<code>.<n>`, so `-TestId 'MP.CNT.*'`
runs one pack's tests. In every case only packs whose files still match the lock file run. `-SkipPack` runs no
pack, and `-PackLock` names another lock file.

```json
{
  "Packs": [ { "Id": "contoso.google-workspace", "Enabled": true } ]
}
```

A pack that cannot run never stops the run. Its tests are reported as not run, with the reason:
`PackUnavailable` (not on this computer, or its files changed), `PackNotAllowed`, `PackBlocked` or
`PackLoadFailed` (see [reason codes](../configuration/applicability.md#reason-codes)).

In the results, a pack's rows have `Source` `Custom` and a [`Package`](../result-schema.md#test-rows) field with
the pack's ID, version, commit and publisher.

To turn a pack off without uninstalling it:

```json
{
  "Packs": [ { "Id": "contoso.google-workspace", "Enabled": false } ]
}
```

### Choosing which packs run

`-Pack` runs only the packs you name, by pack ID or code, with `*` wildcards:

```powershell
Invoke-Maester -Pack ZTA                 # Maester's tests and the Zero Trust Assessment pack
Invoke-Maester -Pack ZTA -SkipBuiltIn    # the Zero Trust Assessment pack only
Invoke-Maester -Pack CNT, maester.*      # two codes or IDs
Invoke-Maester -AllPacks                 # every installed pack
```

A pack you name runs even if it is off by default or turned off in the config (`-AllPacks` still leaves out the
packs the config turns off), and its long-running and
preview tests run without `-IncludeLongRunning` or `-IncludePreview`. Packs you do not name don't run in that
run. The other tests are not affected: select them with `-TestId`, `-Suite` or the other selectors as usual, or
leave them out with `-SkipBuiltIn`. The config equivalent is `Selection.Pack`:

```json
{
  "Selection": { "Pack": [ "ZTA" ] }
}
```

## Connecting to a pack's service

A pack with a connector adds a service, such as `CNT.GoogleWorkspace`. Tests that need it are skipped while it
is not connected, with the command that connects it:

```powershell
Connect-Maester -Service Graph, CNT.GoogleWorkspace -ServiceSetting @{ 'CNT.GoogleWorkspace' = @{ Domain = 'contoso.com' } }
Test-MtConnection -Service CNT.GoogleWorkspace
```

A connector's settings come from `-ServiceSetting`, then from environment variables named
`MAESTER_<SERVICE>_<SETTING>` (for example `MAESTER_CNT_GOOGLEWORKSPACE_DOMAIN`), then from the config:

```json
{
  "Connections": { "CNT.GoogleWorkspace": { "Domain": "contoso.com" } }
}
```

A setting whose name looks like a secret (`Secret`, `Password`, `Token`, `Key`, `Credential`, `Certificate`) is
never read from the config: pass it with `-ServiceSetting` or an environment variable. Pack services are never
part of `-Service All`. `Disconnect-Maester` disconnects them too.

## Packs that ship with Maester

Packs that ship with Maester are part of the module, in its `packs` folder. They are trusted as the module is:
they need no lock entry and no approval. Each one says whether it is on by default; turn one on or off with its
`Packs` entry in the config. If a pack that ships with Maester uses PowerShell Gallery modules, run
`Install-MtPack <id>` once to save them and pin their digests. Their test IDs have no `MP.` prefix: the Zero
Trust Assessment pack's tests are `ZTA.<n>`.

## Writing a pack

See [Writing a pack](./writing-a-pack.md). To learn what Maester checks and why, see
[Pack security](./security.md).

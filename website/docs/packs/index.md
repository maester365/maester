---
title: Maester Packs
sidebar_position: 1
description: Add tests, helpers and connectors that someone else publishes to Maester, checked and pinned before anything runs.
---

# Maester Packs

A Maester Pack is a folder of native tests, the helpers they call and, optionally, connectors to services
Maester does not know, that someone else publishes, usually as a GitHub repository. Installing a pack adds its
tests to every `Invoke-Maester` run in your project. Its results appear in the report like your own custom tests,
never as Maester's own checks.

```powershell
Install-MtPack contoso/maester-google-workspace
Connect-Maester -Service Graph, CNT.GoogleWorkspace
Invoke-Maester
```

Some packs ship with Maester. They need no install and run as soon as they are turned on (see
[Packs that ship with Maester](#packs-that-ship-with-maester)).

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
  Risk        LOW: text files only; every scan passed
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
Invoke-Maester -NonInteractive
```

To install without a prompt, say which risk you accept: `Install-MtPack contoso/pack -NonInteractive -AcceptRisk Medium`.

## Running pack tests

`Invoke-Maester` runs every pack in the lock file whose files still match it. A pack's tests have IDs
`MP.<code>.<n>`, so `-TestId 'MP.CNT.*'` runs one pack's tests, and `-Suite` with a pack's suite ID runs
that pack's tests, including its long-running and preview ones. `-SkipPack` runs no pack, and
`-PackLock` names another lock file.

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
```

A pack you name runs even if it is off by default or turned off in the config, and its long-running and
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
`Install-MtPack <id>` once to save them and pin their digests.

## Writing a pack

See [Writing a pack](./writing-a-pack.md). To learn what Maester checks and why, see
[Pack security](./security.md).
